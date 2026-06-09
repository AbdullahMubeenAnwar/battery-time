import AppKit
import Foundation
import IOKit.ps

final class BatteryMonitor: ObservableObject {
    @Published private(set) var snapshot: BatterySnapshot
    @Published private(set) var estimate: BatteryEstimate
    @Published private(set) var samples: [BatterySample] = []
    @Published private(set) var topProcesses: [ProcessSample] = []
    @Published private(set) var usageReport: BatteryUsageReport

    private let client: PowerSourceClient
    private let estimator: BatteryEstimator
    private let processSampler: ProcessSampler
    private let historyStore: BatteryHistoryStore
    private let powerlogBackfillClient: PowerlogBackfillClient
    private let usageAnalyzer: BatteryUsageAnalyzer
    private let screenActivityMonitor: ScreenActivityMonitor
    private var timer: Timer?
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var usageRange = BatteryUsageRange.day
    private var lastPowerlogBackfillDate: Date?
    private var lastPowerlogBackfillWasAvailable = false
    private var lastPowerlogFallbackReason = "macOS power history has not been imported yet."
    private var isPowerlogBackfillRunning = false

    init(
        client: PowerSourceClient = PowerSourceClient(),
        estimator: BatteryEstimator = BatteryEstimator(),
        processSampler: ProcessSampler = ProcessSampler(),
        historyStore: BatteryHistoryStore = BatteryHistoryStore(),
        powerlogBackfillClient: PowerlogBackfillClient = PowerlogBackfillClient(),
        usageAnalyzer: BatteryUsageAnalyzer = BatteryUsageAnalyzer()
    ) {
        self.client = client
        self.estimator = estimator
        self.processSampler = processSampler
        self.historyStore = historyStore
        self.powerlogBackfillClient = powerlogBackfillClient
        self.usageAnalyzer = usageAnalyzer
        let initialSnapshot = client.snapshot()
        self.screenActivityMonitor = ScreenActivityMonitor(startDate: initialSnapshot.collectedAt)
        self.snapshot = initialSnapshot
        self.estimate = estimator.estimate(snapshot: initialSnapshot, samples: [])
        self.topProcesses = []
        self.usageReport = BatteryUsageReport.empty(range: usageRange, now: initialSnapshot.collectedAt)
        recordSample(from: snapshot)
        recalculateEstimate()
        refreshUsageReport()
        refreshCalibratedHealth()
        refreshChargingLimit()
        refreshTopProcesses()
        refreshPowerlogBackfillIfNeeded(force: true)
        startPowerSourceNotifications()

        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    deinit {
        stopPowerSourceNotifications()
        timer?.invalidate()
    }

    func refresh() {
        snapshot = client.snapshot()
        recordSample(from: snapshot)
        recalculateEstimate()
        refreshCalibratedHealth()
        refreshChargingLimit()
        refreshTopProcesses()
        refreshPowerlogBackfillIfNeeded()
        refreshUsageReport()
    }

    func setUsageRange(_ range: BatteryUsageRange) {
        guard usageRange != range else {
            return
        }

        usageRange = range
        refreshUsageReport()
    }

    func menuBarTitle(format: DisplayFormat, hideWhenFull: Bool = false) -> String {
        if hideWhenFull, snapshot.percentage == 100 {
            return ""
        }

        switch format {
        case .iconOnly, .innerPercentage:
            return ""
        case .percentOnly:
            return percentageText ?? "n/a"
        case .timeOnly:
            return menuBarTimeText ?? "--"
        case .percentAndTime:
            return "\(percentageText ?? "n/a")\n\(menuBarTimeText ?? "--")"
        case .timeAndPercent:
            return "\(menuBarTimeText ?? "--")\n\(percentageText ?? "n/a")"
        }
    }

    var percentageText: String? {
        snapshot.percentage.map { "\($0)%" }
    }

    var timeText: String? {
        estimate.timeText
    }

    private var menuBarTimeText: String? {
        estimate.minutes.map { DurationFormatter.compactBatteryTime(minutes: $0) }
    }

    var drainRateText: String {
        estimate.rateText
    }

    private func recordSample(from snapshot: BatterySnapshot) {
        historyStore.saveSnapshot(snapshot)

        if let screenSample = screenActivityMonitor.recordTick(at: snapshot.collectedAt) {
            historyStore.saveScreenActivity(screenSample)
        }

        guard let percentage = snapshot.percentage else {
            return
        }

        samples.append(
            BatterySample(
                date: snapshot.collectedAt,
                percentage: percentage,
                isPluggedIn: snapshot.isPluggedIn,
                isCharging: snapshot.isCharging
            )
        )

        if samples.count > 120 {
            samples.removeFirst(samples.count - 120)
        }
    }

    private func recalculateEstimate() {
        estimate = estimator.estimate(snapshot: snapshot, samples: samples)
    }

    private func refreshUsageReport() {
        let now = Date()
        let startDate = usageRange.startDate(now: now)
        var batteryPoints = historyStore.batteryPoints(since: startDate)

        if batteryPoints.isEmpty {
            batteryPoints = samples
                .filter { $0.date >= startDate }
                .map {
                    BatteryHistoryPoint(
                        date: $0.date,
                        percentage: $0.percentage,
                        isPluggedIn: $0.isPluggedIn,
                        isCharging: $0.isCharging,
                        source: .app
                    )
                }
        }

        usageReport = usageAnalyzer.report(
            range: usageRange,
            snapshot: snapshot,
            estimate: estimate,
            topProcesses: topProcesses,
            batteryPoints: batteryPoints,
            screenBuckets: historyStore.screenBuckets(since: startDate),
            dataSourceStatus: dataSourceStatus(since: startDate),
            now: now
        )
    }

    private func dataSourceStatus(since startDate: Date) -> HistoryDataSourceStatus {
        let counts = historyStore.counts(since: startDate)

        if counts.powerlogBatteryPoints > 0 || counts.powerlogScreenBuckets > 0 {
            return .hybrid(
                batteryPoints: counts.powerlogBatteryPoints,
                screenBuckets: counts.powerlogScreenBuckets
            )
        }

        let reason = lastPowerlogBackfillWasAvailable
            ? "macOS power history has no rows for this range."
            : lastPowerlogFallbackReason
        return .appOnly(reason: reason, appBatteryPoints: counts.appBatteryPoints)
    }

    private func refreshPowerlogBackfillIfNeeded(force: Bool = false) {
        guard !isPowerlogBackfillRunning else {
            return
        }

        let now = Date()
        if !force,
           let lastPowerlogBackfillDate,
           now.timeIntervalSince(lastPowerlogBackfillDate) < 60 * 60 {
            return
        }

        isPowerlogBackfillRunning = true
        let client = powerlogBackfillClient
        let store = historyStore
        let startDate = BatteryUsageRange.month.startDate(now: now)

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = client.backfill(since: startDate)
            if result.isAvailable {
                store.saveBackfill(result.backfill, now: now)
            }

            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.lastPowerlogBackfillDate = Date()
                self.lastPowerlogBackfillWasAvailable = result.isAvailable
                self.lastPowerlogFallbackReason = result.reason ?? "macOS power history has no rows for this range."
                self.isPowerlogBackfillRunning = false
                self.refreshUsageReport()
            }
        }
    }

    private func startPowerSourceNotifications() {
        guard powerSourceRunLoopSource == nil,
              let source = IOPSNotificationCreateRunLoopSource({ context in
                  guard let context else {
                      return
                  }

                  let monitor = Unmanaged<BatteryMonitor>
                      .fromOpaque(context)
                      .takeUnretainedValue()

                  DispatchQueue.main.async {
                      monitor.refresh()
                  }
              }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))?.takeRetainedValue() else {
            return
        }

        powerSourceRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private func stopPowerSourceNotifications() {
        guard let source = powerSourceRunLoopSource else {
            return
        }

        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        powerSourceRunLoopSource = nil
    }

    private func refreshTopProcesses() {
        let sampler = processSampler
        let appPIDs = Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular || $0.activationPolicy == .accessory }
            .map { Int($0.processIdentifier) })

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let samples = sampler.topProcesses(appPIDs: appPIDs)

            DispatchQueue.main.async {
                self?.topProcesses = samples
                self?.refreshUsageReport()
            }
        }
    }

    private func refreshCalibratedHealth() {
        let client = client

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let health = client.calibratedHealth() else {
                return
            }

            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                var updatedSnapshot = self.snapshot
                updatedSnapshot.healthPercent = health.maximumCapacityPercent ?? updatedSnapshot.healthPercent
                updatedSnapshot.healthCondition = health.condition ?? updatedSnapshot.healthCondition
                updatedSnapshot.cycleCount = health.cycleCount ?? updatedSnapshot.cycleCount
                self.snapshot = updatedSnapshot
                self.refreshUsageReport()
            }
        }
    }

    private func refreshChargingLimit() {
        let client = client

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let limit = client.chargingLimitPercent()

            DispatchQueue.main.async {
                guard let self else { return }
                var updatedSnapshot = self.snapshot
                updatedSnapshot.chargingLimitPercent = limit
                self.snapshot = updatedSnapshot
            }
        }
    }
}

import AppKit
import Foundation
import IOKit.ps
import os

@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var snapshot: BatterySnapshot
    @Published private(set) var estimate: BatteryEstimate
    @Published private(set) var topProcesses: [ProcessSample] = []

    private static let log = Logger(subsystem: "com.abdullah.batterytime", category: "monitor")

    private let client: PowerSourceClient
    private let estimator: BatteryEstimator
    private let processSampler: ProcessSampler
    private var samples: [BatterySample] = []

    // Touched only from the main thread (init/deinit and main-actor methods);
    // marked unsafe so the nonisolated deinit can clean them up.
    private nonisolated(unsafe) var timer: Timer?
    private nonisolated(unsafe) var powerSourceRunLoopSource: CFRunLoopSource?

    private var pendingRefresh: Task<Void, Never>?
    private var lastRefreshDate = Date.distantPast

    private var cachedHealth: ProfiledBatteryHealth?
    private var lastHealthFetch: Date?
    private var isHealthFetchInFlight = false

    private var cachedChargingLimit: Int?
    private var isChargingLimitFetchInFlight = false

    private var lastTopProcessSample: Date?
    private var isTopProcessSampleInFlight = false
    private var topProcessInterest = 0

    /// How stale top-process data may get before a refresh re-samples.
    private static let visibleTopProcessMaxAge: TimeInterval = 45
    private static let hiddenTopProcessMaxAge: TimeInterval = 300
    private static let healthRefetchInterval: TimeInterval = 600

    init(
        client: PowerSourceClient = PowerSourceClient(),
        estimator: BatteryEstimator = BatteryEstimator(),
        processSampler: ProcessSampler = ProcessSampler()
    ) {
        self.client = client
        self.estimator = estimator
        self.processSampler = processSampler
        let initialSnapshot = client.snapshot()
        self.snapshot = initialSnapshot
        self.estimate = estimator.estimate(snapshot: initialSnapshot, samples: [])

        startPowerSourceNotifications()

        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            // Scheduled on the main run loop, so the timer always fires on the main thread.
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        t.tolerance = 10
        RunLoop.main.add(t, forMode: .common)
        timer = t

        refresh()
    }

    deinit {
        // BatteryMonitor lives for the process lifetime (owned by the app model's
        // StateObject), so this runs — if ever — on the main thread during teardown,
        // which Timer.invalidate and run-loop source removal require.
        if let source = powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        timer?.invalidate()
    }

    func refresh(userInitiated: Bool = false) {
        lastRefreshDate = Date()
        var newSnapshot = client.snapshot()
        merge(into: &newSnapshot)
        snapshot = newSnapshot
        recordSample(from: newSnapshot)
        recalculateEstimate()
        refreshCalibratedHealth()
        refreshChargingLimit()
        refreshTopProcesses(maxAge: topProcessMaxAge(userInitiated: userInitiated))
        Self.log.debug("refresh: pct=\(newSnapshot.percentage ?? -1) charging=\(newSnapshot.isCharging) pluggedIn=\(newSnapshot.isPluggedIn) samples=\(self.samples.count)")
    }

    /// Views that display top-process data call this when they appear so sampling
    /// runs at full cadence only while something is showing the result.
    func beginTopProcessUpdates() {
        topProcessInterest += 1
        refreshTopProcesses(maxAge: Self.visibleTopProcessMaxAge)
    }

    func endTopProcessUpdates() {
        topProcessInterest = max(0, topProcessInterest - 1)
    }

    func menuBarTitle(format: DisplayFormat, hideWhenFull: Bool = false) -> String {
        if hideWhenFull, snapshot.percentage == 100 {
            return ""
        }

        let timeDisplay = menuBarDisplayTimeText

        switch format {
        case .iconOnly, .innerPercentage:
            return ""
        case .percentOnly:
            return percentageText ?? "n/a"
        case .timeOnly:
            return timeDisplay
        case .percentAndTime:
            return "\(percentageText ?? "n/a")\n\(timeDisplay)"
        case .timeAndPercent:
            return "\(timeDisplay)\n\(percentageText ?? "n/a")"
        }
    }

    var percentageText: String? {
        snapshot.percentage.map { "\($0)%" }
    }

    var timeText: String? {
        estimate.timeText
    }

    var displayTimeText: String? {
        snapshot.isPluggedIn && !snapshot.isCharging ? "∞" : timeText
    }

    private var menuBarTimeText: String? {
        estimate.minutes.map { DurationFormatter.compactBatteryTime(minutes: $0) }
    }

    private var menuBarDisplayTimeText: String {
        if snapshot.isPluggedIn && !snapshot.isCharging { return "∞" }
        return menuBarTimeText ?? "--"
    }

    var drainRateText: String {
        estimate.rateText
    }

    // MARK: - Sampling

    private func recordSample(from snapshot: BatterySnapshot) {
        guard let percentage = snapshot.percentage else {
            return
        }

        // Notification bursts can fire several refreshes per second; don't let
        // identical samples flood the 120-entry buffer and starve the rolling
        // windows. State transitions are always recorded.
        if let last = samples.last,
           last.percentage == percentage,
           last.isPluggedIn == snapshot.isPluggedIn,
           last.isCharging == snapshot.isCharging,
           snapshot.collectedAt.timeIntervalSince(last.date) < 30 {
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
        Self.log.debug("estimate: minutes=\(self.estimate.minutes ?? -1) rate=\(self.estimate.ratePercentPerHour ?? 0, format: .fixed(precision: 2)) window=\(self.estimate.windowMinutes ?? 0) confidence=\(self.estimate.confidence.rawValue)")
    }

    // MARK: - Power source notifications

    private func startPowerSourceNotifications() {
        guard powerSourceRunLoopSource == nil,
              let source = IOPSNotificationCreateRunLoopSource({ context in
                  guard let context else {
                      return
                  }

                  let monitor = Unmanaged<BatteryMonitor>
                      .fromOpaque(context)
                      .takeUnretainedValue()

                  // IOPS callbacks fire on the run loop the source is installed
                  // on — the main run loop.
                  MainActor.assumeIsolated {
                      monitor.powerSourceDidChange()
                  }
              }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))?.takeRetainedValue() else {
            return
        }

        powerSourceRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    /// Plug/unplug events deliver several notifications back to back. Refresh
    /// immediately on the first one, then coalesce the rest into a single
    /// trailing refresh one second later.
    private func powerSourceDidChange() {
        guard pendingRefresh == nil else {
            return
        }

        if Date().timeIntervalSince(lastRefreshDate) > 1 {
            Self.log.debug("power source changed: refreshing now")
            refresh()
            return
        }

        Self.log.debug("power source changed: coalescing")
        pendingRefresh = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, !Task.isCancelled else {
                return
            }

            self.pendingRefresh = nil
            self.refresh()
        }
    }

    // MARK: - Background reads

    /// Re-applies the slow background-fetched values onto a freshly built snapshot.
    private func merge(into snapshot: inout BatterySnapshot) {
        if let cachedHealth {
            snapshot.healthPercent = cachedHealth.maximumCapacityPercent ?? snapshot.healthPercent
            snapshot.healthCondition = cachedHealth.condition ?? snapshot.healthCondition
            snapshot.cycleCount = cachedHealth.cycleCount ?? snapshot.cycleCount
        }

        snapshot.chargingLimitPercent = cachedChargingLimit
    }

    private func refreshCalibratedHealth() {
        if let lastHealthFetch, Date().timeIntervalSince(lastHealthFetch) < Self.healthRefetchInterval {
            return
        }

        guard !isHealthFetchInFlight else {
            return
        }

        isHealthFetchInFlight = true
        let client = client

        Task.detached(priority: .utility) { [weak self] in
            let health = client.calibratedHealth()
            await self?.healthFetchCompleted(health)
        }
    }

    private func healthFetchCompleted(_ health: ProfiledBatteryHealth?) {
        isHealthFetchInFlight = false
        lastHealthFetch = Date()

        guard let health else {
            Self.log.info("calibrated health fetch failed; keeping previous values")
            return
        }

        cachedHealth = health
        var updatedSnapshot = snapshot
        merge(into: &updatedSnapshot)
        snapshot = updatedSnapshot
        Self.log.info("calibrated health: capacity=\(health.maximumCapacityPercent ?? -1)% cycles=\(health.cycleCount ?? -1)")
    }

    private func refreshChargingLimit() {
        guard !isChargingLimitFetchInFlight else {
            return
        }

        isChargingLimitFetchInFlight = true
        let client = client

        Task.detached(priority: .utility) { [weak self] in
            let limit = client.chargingLimitPercent()
            await self?.chargingLimitFetchCompleted(limit)
        }
    }

    private func chargingLimitFetchCompleted(_ limit: Int?) {
        isChargingLimitFetchInFlight = false

        guard limit != cachedChargingLimit else {
            return
        }

        cachedChargingLimit = limit
        var updatedSnapshot = snapshot
        merge(into: &updatedSnapshot)
        snapshot = updatedSnapshot
    }

    private func topProcessMaxAge(userInitiated: Bool) -> TimeInterval {
        if userInitiated {
            return 5
        }

        return topProcessInterest > 0 ? Self.visibleTopProcessMaxAge : Self.hiddenTopProcessMaxAge
    }

    private func refreshTopProcesses(maxAge: TimeInterval) {
        guard !isTopProcessSampleInFlight else {
            return
        }

        if let lastTopProcessSample, Date().timeIntervalSince(lastTopProcessSample) < maxAge {
            return
        }

        isTopProcessSampleInFlight = true
        let sampler = processSampler
        let appPIDs = Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular || $0.activationPolicy == .accessory }
            .map { Int($0.processIdentifier) })

        Task.detached(priority: .utility) { [weak self] in
            let started = Date()
            let processes = sampler.topProcesses(appPIDs: appPIDs)
            let duration = Date().timeIntervalSince(started)
            await self?.topProcessSampleCompleted(processes, duration: duration)
        }
    }

    private func topProcessSampleCompleted(_ processes: [ProcessSample], duration: TimeInterval) {
        isTopProcessSampleInFlight = false
        lastTopProcessSample = Date()
        topProcesses = processes
        Self.log.debug("top processes: \(processes.count) rows in \(duration, format: .fixed(precision: 2))s")
    }
}

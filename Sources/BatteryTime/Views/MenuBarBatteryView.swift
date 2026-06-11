import AppKit
import SwiftUI

struct MenuBarBatteryView: View {
    var openMainWindow: (() -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?

    @EnvironmentObject private var batteryMonitor: BatteryMonitor
    @Environment(\.openWindow) private var openWindow

    // Sections
    @AppStorage(BatteryTimeAppSettings.popoverShowDetailsKey)
    private var showDetails = BatteryTimeAppSettings.defaultPopoverShowDetails
    @AppStorage(BatteryTimeAppSettings.popoverShowTopProcessKey)
    private var showTopProcess = BatteryTimeAppSettings.defaultPopoverShowTopProcess
    @AppStorage(BatteryTimeAppSettings.popoverShowUptimeKey)
    private var showUptime = BatteryTimeAppSettings.defaultPopoverShowUptime

    // Layout
    @AppStorage(BatteryTimeAppSettings.popoverCompactKey)
    private var compact = BatteryTimeAppSettings.defaultPopoverCompact

    // Individual rows
    @AppStorage(BatteryTimeAppSettings.popoverShowChargeKey)
    private var showCharge = BatteryTimeAppSettings.defaultPopoverShowCharge
    @AppStorage(BatteryTimeAppSettings.popoverShowTimeRemainingKey)
    private var showTimeRemaining = BatteryTimeAppSettings.defaultPopoverShowTimeRemaining
    @AppStorage(BatteryTimeAppSettings.popoverShowDrainRateKey)
    private var showDrainRate = BatteryTimeAppSettings.defaultPopoverShowDrainRate
    @AppStorage(BatteryTimeAppSettings.popoverShowCapacityKey)
    private var showCapacity = BatteryTimeAppSettings.defaultPopoverShowCapacity
    @AppStorage(BatteryTimeAppSettings.popoverShowTemperatureKey)
    private var showTemperature = BatteryTimeAppSettings.defaultPopoverShowTemperature
    @AppStorage(BatteryTimeAppSettings.popoverShowEstimateSourceKey)
    private var showEstimateSource = BatteryTimeAppSettings.defaultPopoverShowEstimateSource
    @AppStorage(BatteryTimeAppSettings.popoverShowChargeLimitKey)
    private var showChargeLimit = BatteryTimeAppSettings.defaultPopoverShowChargeLimit
    @AppStorage(BatteryTimeAppSettings.popoverShowDrainStatusKey)
    private var showDrainStatus = BatteryTimeAppSettings.defaultPopoverShowDrainStatus

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            // Header — always visible
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(batteryMonitor.snapshot.stateTitle)
                        .font(.headline)
                    Text(statusText)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    Text("Updated \(DurationFormatter.shortTime(batteryMonitor.snapshot.collectedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: batteryMonitor.snapshot.symbolName)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }

            // Detail rows section
            if showDetails {
                Divider()

                VStack(alignment: .leading, spacing: compact ? 5 : 8) {
                    if showCharge {
                        detailRow("Charge", batteryMonitor.percentageText ?? "--")
                    }
                    if showChargeLimit, let limit = batteryMonitor.snapshot.chargingLimitPercent {
                        detailRow("Charge Limit", "\(limit)%")
                    }
                    if showTimeRemaining {
                        detailRow(
                            batteryMonitor.snapshot.isCharging ? "Time to Full" : "Runtime",
                            batteryMonitor.displayTimeText ?? "--"
                        )
                    }
                    if showDrainRate {
                        detailRow(rateTitle, rateValue)
                    }
                    if showCapacity {
                        detailRow("Capacity", batteryMonitor.snapshot.healthText)
                    }
                    if showTemperature {
                        detailRow("Temperature", BatteryDiagnosticsFormatter.temperature(batteryMonitor.snapshot.temperatureCelsius))
                    }
                    let needsEstimate = !batteryMonitor.snapshot.isPluggedIn || batteryMonitor.snapshot.isCharging
                    if showEstimateSource && needsEstimate {
                        detailRow("Estimate Source", batteryMonitor.estimate.sourceText)
                    }
                    if showDrainStatus && needsEstimate && batteryMonitor.estimate.ratePercentPerHour == nil {
                        detailRow("Drain Status", "Needs samples")
                    }
                }
            }

            // Top process section
            if showTopProcess, let topProcess = batteryMonitor.topProcesses.first {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    detailRow("Highest Impact", topProcess.name)

                    Text("Higher energy impact can reduce remaining runtime.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Highest energy impact, \(topProcess.accessibilityText)")
            }

            Divider()

            // Uptime footer
            if showUptime {
                uptimeFooter
            }

            // Action buttons — always visible
            HStack {
                Button("Open Window") {
                    if let openMainWindow {
                        openMainWindow()
                    } else {
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
                .help("Open the BatteryTime window")
                .glassButtonStyle()

                Spacer()

                Button("Refresh") {
                    batteryMonitor.refresh(userInitiated: true)
                }
                .keyboardShortcut("r")
                .help("Refresh battery data")
                .glassButtonStyle()
            }
        }
        .padding(compact ? 10 : 16)
        .help("\(batteryMonitor.snapshot.stateTitle). \(statusText)")
        .accessibilityElement(children: .contain)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: PopoverHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(PopoverHeightKey.self) { height in
            onHeightChange?(height)
        }
        .onAppear {
            batteryMonitor.beginTopProcessUpdates()
        }
        .onDisappear {
            batteryMonitor.endTopProcessUpdates()
        }
    }

    private var uptimeFooter: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let uptime = SystemUptimeFormatter.uptimeText(now: context.date)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("Uptime", systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Text(uptime)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(.caption)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
            .help("Uptime: \(uptime)")
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Uptime, \(uptime)")
        }
    }

    private var statusText: String {
        if let time = batteryMonitor.displayTimeText {
            return "\(time) \(batteryMonitor.snapshot.timeCaption)"
        }

        return batteryMonitor.percentageText ?? "No data"
    }

    private var rateTitle: String {
        if batteryMonitor.snapshot.isCharging { return "Charge Rate" }
        if batteryMonitor.snapshot.isPluggedIn { return "Power Rate" }
        return "Drain Rate"
    }

    private var rateValue: String {
        if batteryMonitor.snapshot.isPluggedIn && !batteryMonitor.snapshot.isCharging {
            return "Paused"
        }
        return batteryMonitor.drainRateText
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

// MARK: - Height preference key

private struct PopoverHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

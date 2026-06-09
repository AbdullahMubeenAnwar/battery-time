import AppKit
import SwiftUI

struct MenuBarBatteryView: View {
    var openMainWindow: (() -> Void)?

    @EnvironmentObject private var batteryMonitor: BatteryMonitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                detailRow("Charge", batteryMonitor.percentageText ?? "--")
                if let limit = batteryMonitor.snapshot.chargingLimitPercent {
                    detailRow("Charge Limit", "\(limit)%")
                }
                detailRow(batteryMonitor.snapshot.isCharging ? "Time to Full" : "Runtime", batteryMonitor.timeText ?? "--")
                detailRow(rateTitle, rateValue)
                detailRow("Capacity", batteryMonitor.snapshot.healthText)
                detailRow("Temperature", BatteryDiagnosticsFormatter.temperature(batteryMonitor.snapshot.temperatureCelsius))
                detailRow("Estimate Source", batteryMonitor.estimate.sourceText)
                if batteryMonitor.estimate.ratePercentPerHour == nil {
                    detailRow("Drain Status", "Needs samples")
                }
            }

            if let topProcess = batteryMonitor.topProcesses.first {
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

            uptimeFooter

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
                .buttonStyle(.glass)

                Spacer()

                Button("Refresh") {
                    batteryMonitor.refresh()
                }
                .keyboardShortcut("r")
                .help("Refresh battery data")
                .buttonStyle(.glass)

            }
        }
        .padding(16)
        .help("\(batteryMonitor.snapshot.stateTitle). \(statusText)")
        .accessibilityElement(children: .contain)
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
        if let time = batteryMonitor.timeText {
            return "\(time) \(batteryMonitor.snapshot.timeCaption)"
        }

        return batteryMonitor.percentageText ?? "No data"
    }

    private var rateTitle: String {
        if batteryMonitor.snapshot.isCharging {
            return "Charge Rate"
        }

        if batteryMonitor.snapshot.isPluggedIn {
            return "Power Rate"
        }

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

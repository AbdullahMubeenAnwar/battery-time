import SwiftUI

struct BatteryDetailView: View {
    @EnvironmentObject private var batteryMonitor: BatteryMonitor

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 12) {
                VStack(alignment: .leading, spacing: 22) {
                    OverviewHeaderView(
                        title: batteryMonitor.snapshot.stateTitle,
                        value: primaryStatus,
                        updatedAt: batteryMonitor.snapshot.collectedAt,
                        systemImage: batteryMonitor.snapshot.symbolName,
                        confidence: batteryMonitor.estimate.confidence,
                        source: batteryMonitor.estimate.sourceText
                    )

                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
                        MetricTile(
                            title: "Charge",
                            value: batteryMonitor.percentageText ?? "--",
                            caption: batteryMonitor.snapshot.powerSource,
                            systemImage: batteryMonitor.snapshot.symbolName
                        )

                        MetricTile(
                            title: batteryMonitor.snapshot.isCharging ? "Time to Full" : "Runtime",
                            value: batteryMonitor.timeText ?? "--",
                            caption: batteryMonitor.estimate.sourceText,
                            systemImage: "clock"
                        )

                        MetricTile(
                            title: rateTitle,
                            value: rateValue,
                            caption: rateCaption,
                            systemImage: rateSystemImage
                        )

                        MetricTile(
                            title: "Capacity",
                            value: batteryMonitor.snapshot.healthText,
                            caption: "Maximum capacity",
                            systemImage: "heart.text.square"
                        )
                    }

                    Text("Diagnostics")
                        .font(.headline)
                        .padding(.top, 2)

                    diagnosticGrid
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    private var diagnosticGrid: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 12) {
                    batteryStatusSection
                    batteryHealthSection
                }
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: 12) {
                    powerAdapterSection
                    TopProcessesSectionView(processes: batteryMonitor.topProcesses)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }

            VStack(spacing: 12) {
                batteryStatusSection
                powerAdapterSection
                batteryHealthSection
                TopProcessesSectionView(processes: batteryMonitor.topProcesses)
            }
        }
    }

    private var batteryStatusSection: some View {
        let limitRow: (String, String)? = batteryMonitor.snapshot.chargingLimitPercent.map {
            ("Charge Limit", "\($0)%")
        }
        let rows: [(String, String)] = [
            ("Charge", BatteryDiagnosticsFormatter.percent(batteryMonitor.snapshot.percentage)),
            ("Power Source", batteryMonitor.snapshot.powerSource),
            (
                batteryMonitor.snapshot.isCharging ? "Time to Full" : "Runtime",
                BatteryDiagnosticsFormatter.minutes(
                    batteryMonitor.snapshot.displayMinutes,
                    calculatingWhenMissing: true
                )
            ),
            ("Estimate Source", batteryMonitor.estimate.sourceText),
            ("State", batteryMonitor.snapshot.stateTitle)
        ] + (limitRow.map { [$0] } ?? [])
        return DiagnosticSectionView(title: "Battery Status", rows: rows)
    }

    private var powerAdapterSection: some View {
        DiagnosticSectionView(
            title: "Power Adapter",
            rows: [
                (
                    "Adapter Power",
                    BatteryDiagnosticsFormatter.watts(
                        batteryMonitor.snapshot.adapterPowerWatts,
                        connected: batteryMonitor.snapshot.adapterConnected
                    )
                ),
                ("Charging", BatteryDiagnosticsFormatter.yesNo(batteryMonitor.snapshot.isCharging))
            ]
        )
    }

    private var batteryHealthSection: some View {
        DiagnosticSectionView(
            title: "Battery Health",
            rows: [
                ("Maximum Capacity", batteryMonitor.snapshot.healthText),
                ("Cycle Count", BatteryDiagnosticsFormatter.integer(batteryMonitor.snapshot.cycleCount)),
                ("Current", BatteryDiagnosticsFormatter.amperage(batteryMonitor.snapshot.amperageMilliamps)),
                ("Voltage", BatteryDiagnosticsFormatter.voltage(batteryMonitor.snapshot.voltageMillivolts)),
                ("Temperature", BatteryDiagnosticsFormatter.temperature(batteryMonitor.snapshot.temperatureCelsius))
            ]
        )
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 260), spacing: 12)
        ]
    }

    private var primaryStatus: String {
        if let time = batteryMonitor.timeText {
            return "\(time) \(batteryMonitor.snapshot.timeCaption)"
        }

        if let percentage = batteryMonitor.percentageText {
            return "\(percentage) available"
        }

        return "No battery data"
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

    private var rateCaption: String {
        if batteryMonitor.snapshot.isCharging {
            switch batteryMonitor.estimate.confidence {
            case .stable:
                return "Recent charging is consistent."
            case .changingFast:
                return "Recent charging changed, so time to full can move quickly."
            case .learning:
                return "Needs 10 minutes of charging samples."
            case .pluggedIn:
                return "The battery is connected to power."
            case .unavailable:
                return "Battery estimate data is unavailable."
            }
        }

        if batteryMonitor.snapshot.isPluggedIn {
            return "Battery is connected to power."
        }

        return batteryMonitor.estimate.confidence.explanation
    }

    private var rateSystemImage: String {
        if batteryMonitor.snapshot.isCharging {
            return "bolt.fill"
        }

        if batteryMonitor.snapshot.isPluggedIn {
            return "powerplug"
        }

        return "gauge.with.dots.needle.50percent"
    }
}

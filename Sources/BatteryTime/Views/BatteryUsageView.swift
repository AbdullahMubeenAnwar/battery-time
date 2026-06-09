import SwiftUI

struct BatteryUsageView: View {
    @EnvironmentObject private var batteryMonitor: BatteryMonitor
    @State private var selectedRange = BatteryUsageRange.day

    private var report: BatteryUsageReport {
        batteryMonitor.usageReport
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 12) {
                VStack(alignment: .leading, spacing: 18) {
                    summaryGrid

                    if !report.insights.isEmpty {
                        UsageInsightStrip(insights: report.insights)
                    }

                    rangePicker

                    UsageChartPanel(
                        title: "Battery Level",
                        subtitle: "Battery percentage, power connection, and low-battery threshold."
                    ) {
                        BatteryLevelUsageChart(
                            points: report.batteryPoints,
                            range: selectedRange,
                            generatedAt: report.generatedAt
                        )
                        .frame(height: 250)
                    }

                    UsageChartPanel(
                        title: "Screen Active Usage",
                        subtitle: "Display-on time grouped by \(selectedRange.screenBucketUnitName)."
                    ) {
                        ScreenActiveUsageChart(
                            buckets: report.screenBuckets,
                            range: selectedRange
                        )
                        .frame(height: 230)
                    }

                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onAppear {
            batteryMonitor.setUsageRange(selectedRange)
        }
        .onChange(of: selectedRange) { _, newValue in
            batteryMonitor.setUsageRange(newValue)
        }
    }

    private var summaryGrid: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                UsageSummarySection(
                    title: "Battery Health",
                    systemImage: "heart.text.square",
                    rows: report.healthRows
                )

                UsageSummarySection(
                    title: "Charging",
                    systemImage: "bolt.batteryblock",
                    rows: report.chargingRows
                )
            }

            VStack(spacing: 12) {
                UsageSummarySection(
                    title: "Battery Health",
                    systemImage: "heart.text.square",
                    rows: report.healthRows
                )

                UsageSummarySection(
                    title: "Charging",
                    systemImage: "bolt.batteryblock",
                    rows: report.chargingRows
                )
            }
        }
    }

    private var rangePicker: some View {
        HStack {
            Picker("Usage range", selection: $selectedRange) {
                ForEach(BatteryUsageRange.allCases) { range in
                    Text(range.title)
                        .tag(range)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer()

            Text("Updated \(DurationFormatter.shortTime(report.generatedAt))")
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .contain)
    }
}

private struct UsageSummarySection: View {
    let title: String
    let systemImage: String
    let rows: [UsageSummaryRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    UsageSummaryRowView(
                        row: row,
                        showsDivider: index != rows.count - 1
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .batteryGlassPanel()
        .accessibilityElement(children: .contain)
    }
}

private struct UsageSummaryRowView: View {
    let row: UsageSummaryRow
    let showsDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: row.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)

                    Text(row.caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 16)

                Text(row.value)
                    .font(.callout.weight(.semibold))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .monospacedDigit()
            }
            .frame(minHeight: 42)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(row.title), \(row.value), \(row.caption)")

            if showsDivider {
                Divider()
                    .opacity(0.45)
            }
        }
    }
}

private struct UsageInsightStrip: View {
    let insights: [UsageInsight]

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 160), spacing: 12)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(insights) { insight in
                UsageInsightCard(insight: insight)
            }
        }
    }
}

private struct UsageInsightCard: View {
    let insight: UsageInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: insight.systemImage)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.secondary)

                Text(insight.title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(insight.value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()

            Text(insight.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .batteryGlassPanel()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(insight.title), \(insight.value), \(insight.caption)")
    }

    private var tint: Color {
        switch insight.kind {
        case .neutral:
            return .accentColor
        case .positive:
            return .green
        case .warning:
            return .orange
        case .action:
            return .blue
        }
    }
}

private struct UsageChartPanel<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .batteryGlassPanel()
    }
}

private struct HistorySourceNotice: View {
    let status: HistoryDataSourceStatus

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(status.title)
                    .font(.callout.weight(.medium))

                Text(status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        } icon: {
            Image(systemName: status.isPowerlogAvailable ? "externaldrive.connected.to.line.below" : "clock.arrow.circlepath")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(status.isPowerlogAvailable ? .green : .secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .batteryGlassPanel()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.title). \(status.detail)")
    }
}

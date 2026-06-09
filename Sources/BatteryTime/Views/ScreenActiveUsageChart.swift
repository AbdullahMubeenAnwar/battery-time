import Charts
import SwiftUI

struct ScreenActiveUsageChart: View {
    let buckets: [ScreenUsageBucket]
    let range: BatteryUsageRange

    @State private var selection = UsageChartSelection<ScreenUsageChartBucket>()

    private var chartBuckets: [ScreenUsageChartBucket] {
        buckets.map(ScreenUsageChartBucket.init(bucket:))
    }

    private var bucketByCategory: [String: ScreenUsageChartBucket] {
        Dictionary(uniqueKeysWithValues: chartBuckets.map { ($0.xCategory, $0) })
    }

    var body: some View {
        if chartBuckets.allSatisfy({ $0.activeSeconds <= 0 }) {
            ContentUnavailableView(
                "Collecting Screen Activity",
                systemImage: "display",
                description: Text("Screen active usage appears after BatteryTime records display-on time or imports macOS power history.")
            )
            .frame(maxWidth: .infinity, minHeight: 190)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                screenLegend

                Chart {
                    ForEach(chartBuckets) { bucket in
                        BarMark(
                            x: .value("Time", bucket.xCategory),
                            y: .value("Screen active", bucket.activeMinutes),
                            width: .ratio(0.75)
                        )
                        .foregroundStyle(barGradient(for: bucket))
                        .cornerRadius(4)
                    }

                    if let pinned = selection.pinned {
                        selectedRule(for: pinned, isPinned: true)
                    }

                    if selection.pinned == nil, let hovered = selection.hovered {
                        selectedRule(for: hovered, isPinned: false)
                    }
                }
                .chartYScale(domain: 0...maxYMinutes)
                .chartXAxis {
                    AxisMarks(values: xAxisCategories) { value in
                        if let label = value.as(String.self),
                           let bucket = bucketByCategory[label] {
                            AxisGridLine()
                                .foregroundStyle(Color.secondary.opacity(0.16))
                            AxisTick()
                                .foregroundStyle(Color.secondary.opacity(0.45))
                            AxisValueLabel {
                                Text(axisText(bucket.startDate))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: yAxisValues) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(0.18))
                        AxisTick()
                            .foregroundStyle(Color.secondary.opacity(0.45))
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text(yAxisText(minutes))
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(Color.primary.opacity(0.025))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .chartOverlay { proxy in
                    interactionOverlay(proxy: proxy)
                }
                .frame(minHeight: 190)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
            }
        }
    }

    @ChartContentBuilder
    private func selectedRule(for bucket: ScreenUsageChartBucket, isPinned: Bool) -> some ChartContent {
        RuleMark(x: .value(isPinned ? "Pinned" : "Selected", bucket.xCategory))
            .foregroundStyle((isPinned ? Color.primary : Color.blue).opacity(isPinned ? 0.68 : 0.50))
            .lineStyle(StrokeStyle(lineWidth: isPinned ? 1.5 : 1, dash: isPinned ? [] : [3, 4]))
            .annotation(position: .top, alignment: .center) {
                UsageChartCallout(
                    title: "\(durationText(minutes: bucket.activeMinutes)) active",
                    rows: [
                        windowText(bucket),
                        bucket.source.displayName
                    ],
                    tint: .blue,
                    isPinned: isPinned
                )
            }
    }

    private var screenLegend: some View {
        HStack(spacing: 12) {
            legendItem("Active", color: .blue.opacity(0.82))
            legendItem("Under 1m", color: .blue.opacity(0.25))
            Spacer(minLength: 0)
            selectedSummary
        }
        .font(.caption)
    }

    private var selectedSummary: some View {
        Group {
            if let bucket = selection.pinned ?? selection.hovered {
                Text("\(durationText(minutes: bucket.activeMinutes)) at \(axisText(bucket.startDate))")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .monospacedDigit()
            } else {
                Text("\(durationText(minutes: totalMinutes)) total")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .monospacedDigit()
            }
        }
    }

    private func legendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 7)

            Text(title)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }

    private func interactionOverlay(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        selection.setHovered(targetBucket(at: location, proxy: proxy, geometry: geometry))
                    case .ended:
                        selection.clearHover()
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            guard let target = targetBucket(at: value.location, proxy: proxy, geometry: geometry) else {
                                selection.clearPinned()
                                return
                            }

                            selection.pin(target)
                        }
                )
        }
    }

    private func targetBucket(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) -> ScreenUsageChartBucket? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let plotRect = geometry[plotFrame]
        guard plotRect.contains(location),
              let label = proxy.value(atX: location.x - plotRect.origin.x, as: String.self) else {
            return nil
        }

        if let bucket = bucketByCategory[label] {
            return bucket
        }

        let x = location.x - plotRect.origin.x
        return chartBuckets.min {
            let aX = proxy.position(forX: $0.xCategory) ?? 0
            let bX = proxy.position(forX: $1.xCategory) ?? 0
            return abs(aX - x) < abs(bX - x)
        }
    }

    private var totalMinutes: Double {
        chartBuckets.reduce(0) { $0 + $1.activeMinutes }
    }

    private var maxYMinutes: Double {
        let observed = chartBuckets.map(\.activeMinutes).max() ?? 0
        switch range {
        case .day:
            guard observed > 0 else { return 60 }
            return max(15, ceil(observed / 15) * 15)
        case .week, .month:
            let roundedToHour = ceil(max(observed, 60) / 60) * 60
            return max(60, roundedToHour)
        }
    }

    private var yAxisValues: [Double] {
        [0, maxYMinutes / 2, maxYMinutes]
    }

    private var xAxisCategories: [String] {
        guard !chartBuckets.isEmpty else { return [] }
        let stride: Int
        switch range {
        case .day:   stride = 4   // every 4h label
        case .week:  stride = 1   // every day label (7 total)
        case .month: stride = 5   // every 5 days label
        }
        return chartBuckets.enumerated().compactMap { index, bucket in
            index % stride == 0 ? bucket.xCategory : nil
        }
    }

    private var accessibilityLabel: String {
        var label = "Screen active usage chart, \(durationText(minutes: totalMinutes)) total across \(chartBuckets.count) \(range.screenBucketUnitName) buckets."
        if let selected = selection.pinned ?? selection.hovered {
            label += " Selected \(durationText(minutes: selected.activeMinutes)) active, \(windowText(selected)), \(selected.source.displayName)."
        }
        return label
    }

    private func barGradient(for bucket: ScreenUsageChartBucket) -> LinearGradient {
        let opacity: Double = bucket.isNearZero ? 0.25 : 0.85
        return LinearGradient(
            colors: [.blue.opacity(opacity), .blue.opacity(opacity * 0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func axisText(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch range {
        case .day:
            formatter.timeStyle = .short
            formatter.dateStyle = .none
        case .week, .month:
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }

    private func windowText(_ bucket: ScreenUsageChartBucket) -> String {
        let formatter = DateFormatter()
        switch range {
        case .day:
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return "\(formatter.string(from: bucket.startDate)) to \(formatter.string(from: bucket.endDate))"
        case .week, .month:
            formatter.dateFormat = "MMM d"
            return formatter.string(from: bucket.startDate)
        }
    }

    private func yAxisText(_ minutes: Double) -> String {
        if minutes >= 60 {
            let hours = Int(minutes / 60)
            let remainder = Int(minutes.truncatingRemainder(dividingBy: 60))
            return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
        }

        return "\(Int(minutes))m"
    }

    private func durationText(minutes: Double) -> String {
        let roundedMinutes = max(0, Int(round(minutes)))
        let hours = roundedMinutes / 60
        let remainingMinutes = roundedMinutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(remainingMinutes)m"
    }
}

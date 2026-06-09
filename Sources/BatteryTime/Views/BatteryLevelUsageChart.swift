import Charts
import SwiftUI

struct BatteryLevelUsageChart: View {
    let points: [BatteryHistoryPoint]
    let range: BatteryUsageRange
    let generatedAt: Date

    @State private var selection = UsageChartSelection<BatteryLevelChartPoint>()

    private var chartPoints: [BatteryLevelChartPoint] {
        points.map(BatteryLevelChartPoint.init(historyPoint:))
    }

    private var segments: [BatteryLevelChartSegment] {
        BatteryLevelChartSegment.segments(from: chartPoints)
    }

    private var chargingIntervals: [ChargingInterval] {
        ChargingInterval.intervals(
            from: chartPoints,
            range: range,
            generatedAt: generatedAt
        )
    }

    var body: some View {
        if chartPoints.count < 2 {
            ContentUnavailableView(
                "Collecting Battery History",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Battery level history appears as BatteryTime collects samples or imports macOS power history.")
            )
            .frame(maxWidth: .infinity, minHeight: 210)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                batteryLegend

                Chart {
                    ForEach(chargingIntervals) { interval in
                        RectangleMark(
                            xStart: .value("Power connected", interval.startDate),
                            xEnd: .value("Power disconnected", interval.endDate),
                            yStart: .value("Minimum", 0),
                            yEnd: .value("Maximum", 100)
                        )
                        .foregroundStyle(Color.green.opacity(interval.isCharging ? 0.16 : 0.10))
                    }

                    RuleMark(y: .value("Low battery", 20))
                        .foregroundStyle(Color.red.opacity(0.34))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .leading, alignment: .center) {
                            Text("20%")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }

                    ForEach(segments) { segment in
                        ForEach(segment.points) { point in
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("Battery", point.percentage),
                                series: .value("Segment", segment.id)
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(color(for: segment.band))
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        }
                    }

                    if let preview = selection.preview {
                        RuleMark(x: .value("Preview", preview.date))
                            .foregroundStyle(Color.secondary.opacity(0.36))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))

                        PointMark(
                            x: .value("Preview time", preview.date),
                            y: .value("Preview battery", preview.percentage)
                        )
                        .foregroundStyle(color(for: preview.band).opacity(0.55))
                        .symbolSize(54)
                    }

                    if let pinned = selection.pinned {
                        selectedRule(for: pinned, isPinned: true)
                    }

                    if selection.pinned == nil, let hovered = selection.hovered {
                        selectedRule(for: hovered, isPinned: false)
                    }
                }
                .chartXScale(domain: startDate...generatedAt)
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: xAxisValues) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(0.18))
                        AxisTick()
                            .foregroundStyle(Color.secondary.opacity(0.45))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(axisText(date))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 20, 50, 100]) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(0.18))
                        AxisTick()
                            .foregroundStyle(Color.secondary.opacity(0.45))
                        AxisValueLabel {
                            if let percent = value.as(Int.self) {
                                Text("\(percent)%")
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
                .frame(minHeight: 214)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
            }
        }
    }

    @ChartContentBuilder
    private func selectedRule(for point: BatteryLevelChartPoint, isPinned: Bool) -> some ChartContent {
        RuleMark(x: .value(isPinned ? "Pinned" : "Selected", point.date))
            .foregroundStyle((isPinned ? Color.primary : color(for: point.band)).opacity(isPinned ? 0.68 : 0.50))
            .lineStyle(StrokeStyle(lineWidth: isPinned ? 1.5 : 1, dash: isPinned ? [] : [3, 4]))
            .annotation(position: .top, alignment: .center) {
                UsageChartCallout(
                    title: "\(point.percentage)% battery",
                    rows: [
                        timeText(point.date),
                        point.powerStateText,
                        point.source.displayName
                    ],
                    tint: color(for: point.band),
                    isPinned: isPinned
                )
            }

        PointMark(
            x: .value(isPinned ? "Pinned time" : "Selected time", point.date),
            y: .value(isPinned ? "Pinned battery" : "Selected battery", point.percentage)
        )
        .foregroundStyle(color(for: point.band))
        .symbolSize(isPinned ? 92 : 72)
    }

    private var batteryLegend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                legendItem("Normal", color: color(for: .normal))
                legendItem("Watch", color: color(for: .watch))
                legendItem("Low", color: color(for: .low))
                legendItem("Connected", color: color(for: .connected))
                Spacer(minLength: 0)
                selectedSummary
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    legendItem("Normal", color: color(for: .normal))
                    legendItem("Watch", color: color(for: .watch))
                    legendItem("Low", color: color(for: .low))
                    legendItem("Connected", color: color(for: .connected))
                }
                selectedSummary
            }
        }
        .font(.caption)
    }

    private var selectedSummary: some View {
        Group {
            if let point = selection.pinned ?? selection.hovered {
                Text("\(point.percentage)% at \(timeText(point.date))")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .monospacedDigit()
            } else {
                Text("Latest \(chartPoints.last?.percentage ?? 0)%")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .monospacedDigit()
            }
        }
    }

    private func legendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

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
                        selection.setHovered(targetPoint(at: location, proxy: proxy, geometry: geometry))
                    case .ended:
                        selection.clearHover()
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            guard let target = targetPoint(at: value.location, proxy: proxy, geometry: geometry) else {
                                selection.clearPinned()
                                return
                            }

                            selection.pin(target)
                        }
                )
        }
    }

    private func targetPoint(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) -> BatteryLevelChartPoint? {
        guard let plotFrame = proxy.plotFrame else {
            return nil
        }

        let plotRect = geometry[plotFrame]
        guard plotRect.contains(location),
              let date = proxy.value(atX: location.x - plotRect.origin.x, as: Date.self) else {
            return nil
        }

        return chartPoints.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }

    private var startDate: Date {
        range.startDate(now: generatedAt)
    }

    private var xAxisValues: [Date] {
        let step: TimeInterval
        switch range {
        case .day:   step = 4 * 60 * 60
        case .week:  step = 24 * 60 * 60
        case .month: step = 5 * 24 * 60 * 60
        }
        var dates: [Date] = []
        var offset: TimeInterval = 0

        while offset < range.duration {
            dates.append(startDate.addingTimeInterval(offset))
            offset += step
        }

        dates.append(generatedAt)
        return dates
    }

    private var accessibilityLabel: String {
        guard let first = chartPoints.first, let last = chartPoints.last else {
            return "Battery level chart"
        }

        var label = "Battery level chart, \(first.percentage) percent at \(timeText(first.date)), \(last.percentage) percent at \(timeText(last.date))."
        if let selected = selection.pinned ?? selection.hovered {
            label += " Selected \(selected.percentage) percent at \(timeText(selected.date)), \(selected.powerStateText), \(selected.source.displayName)."
        }
        return label
    }

    private func color(for band: BatteryLevelBand) -> Color {
        switch band {
        case .normal:
            return .accentColor
        case .watch:
            return .orange
        case .low:
            return .red
        case .connected:
            return .green
        }
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

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
        } else {
            formatter.timeStyle = .short
            formatter.dateStyle = .short
        }

        return formatter.string(from: date)
    }
}

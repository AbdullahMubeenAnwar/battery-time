import Foundation

struct BatteryUsageAnalyzer {
    func report(
        range: BatteryUsageRange,
        snapshot: BatterySnapshot,
        estimate: BatteryEstimate,
        topProcesses: [ProcessSample],
        batteryPoints rawBatteryPoints: [BatteryHistoryPoint],
        screenBuckets rawScreenBuckets: [ScreenUsageBucket],
        dataSourceStatus: HistoryDataSourceStatus,
        now: Date = Date()
    ) -> BatteryUsageReport {
        let rangeStart = range.startDate(now: now)
        let batteryPoints = rawBatteryPoints
            .filter { $0.date >= rangeStart && $0.date <= now }
            .sorted { $0.date < $1.date }
        let lastChargeSession = self.lastChargeSession(from: batteryPoints)
        let screenBuckets = groupedScreenBuckets(
            range: range,
            rawBuckets: rawScreenBuckets,
            now: now
        )

        return BatteryUsageReport(
            range: range,
            generatedAt: now,
            batteryPoints: displayBatteryPoints(from: batteryPoints),
            screenBuckets: screenBuckets,
            insights: insights(
                range: range,
                snapshot: snapshot,
                topProcesses: topProcesses,
                batteryPoints: batteryPoints,
                screenBuckets: screenBuckets,
                lastChargeSession: lastChargeSession,
                dataSourceStatus: dataSourceStatus
            ),
            healthRows: healthRows(snapshot: snapshot),
            chargingRows: chargingRows(
                snapshot: snapshot,
                estimate: estimate,
                lastChargeSession: lastChargeSession
            ),
            lastChargeSession: lastChargeSession,
            dataSourceStatus: dataSourceStatus
        )
    }

    private func displayBatteryPoints(from points: [BatteryHistoryPoint]) -> [BatteryHistoryPoint] {
        let targetCount = 520
        guard points.count > targetCount else {
            return points
        }

        let strideValue = max(1, Int(ceil(Double(points.count) / Double(targetCount))))
        var sampled = points.enumerated().compactMap { index, point in
            index % strideValue == 0 ? point : nil
        }

        if let last = points.last, sampled.last != last {
            sampled.append(last)
        }

        return sampled
    }

    private func groupedScreenBuckets(
        range: BatteryUsageRange,
        rawBuckets: [ScreenUsageBucket],
        now: Date
    ) -> [ScreenUsageBucket] {
        let starts = screenBucketStarts(range: range, now: now)

        return starts.map { startDate in
            let endDate = startDate.addingTimeInterval(range.screenBucketInterval)
            let activeSeconds = rawBuckets.reduce(0) { total, bucket in
                let overlapStart = max(bucket.startDate, startDate)
                let overlapEnd = min(bucket.endDate, endDate)
                let overlap = overlapEnd.timeIntervalSince(overlapStart)
                guard overlap > 0 else {
                    return total
                }

                let bucketDuration = max(1, bucket.endDate.timeIntervalSince(bucket.startDate))
                return total + (bucket.activeSeconds * min(1, overlap / bucketDuration))
            }

            return ScreenUsageBucket(
                startDate: startDate,
                endDate: endDate,
                activeSeconds: min(activeSeconds, range.screenBucketInterval),
                source: rawBuckets.contains(where: { $0.source == .powerlog }) ? .powerlog : .app
            )
        }
    }

    private func screenBucketStarts(range: BatteryUsageRange, now: Date) -> [Date] {
        let calendar = Calendar.current

        switch range {
        case .day:
            let currentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            return (0..<24).compactMap {
                calendar.date(byAdding: .hour, value: $0 - 23, to: currentHour)
            }
        case .week:
            let today = calendar.startOfDay(for: now)
            return (0..<7).compactMap {
                calendar.date(byAdding: .day, value: $0 - 6, to: today)
            }
        case .month:
            let today = calendar.startOfDay(for: now)
            return (0..<30).compactMap {
                calendar.date(byAdding: .day, value: $0 - 29, to: today)
            }
        }
    }

    private func healthRows(snapshot: BatterySnapshot) -> [UsageSummaryRow] {
        let status = healthStatus(snapshot: snapshot)
        let capacityCaption = snapshot.healthPercent.map { "\($0)% maximum capacity" } ?? "Maximum capacity unavailable"

        return [
            UsageSummaryRow(
                title: "Status",
                value: status,
                caption: capacityCaption,
                systemImage: "heart.text.square"
            ),
            UsageSummaryRow(
                title: "Cycles",
                value: BatteryDiagnosticsFormatter.integer(snapshot.cycleCount),
                caption: "Battery charge cycles",
                systemImage: "arrow.triangle.2.circlepath"
            ),
            UsageSummaryRow(
                title: "Temperature",
                value: BatteryDiagnosticsFormatter.temperature(snapshot.temperatureCelsius),
                caption: temperatureCaption(snapshot.temperatureCelsius),
                systemImage: "thermometer.medium"
            ),
            UsageSummaryRow(
                title: "Guidance",
                value: healthGuidance(snapshot: snapshot),
                caption: "Based on maximum capacity and condition",
                systemImage: "checkmark.seal"
            )
        ]
    }

    private func chargingRows(
        snapshot: BatterySnapshot,
        estimate: BatteryEstimate,
        lastChargeSession: LastChargeSession?
    ) -> [UsageSummaryRow] {
        let timeTitle = snapshot.isCharging ? "Time to Full" : "Runtime"
        let timeValue = estimate.timeText ?? BatteryDiagnosticsFormatter.minutes(snapshot.displayMinutes, calculatingWhenMissing: true)

        return [
            UsageSummaryRow(
                title: "State",
                value: snapshot.stateTitle,
                caption: chargingCaption(snapshot: snapshot),
                systemImage: snapshot.symbolName
            ),
            UsageSummaryRow(
                title: "Adapter",
                value: BatteryDiagnosticsFormatter.watts(snapshot.adapterPowerWatts, connected: snapshot.adapterConnected),
                caption: snapshot.adapterConnected ? "External power detected" : "Using battery power",
                systemImage: "powerplug"
            ),
            UsageSummaryRow(
                title: timeTitle,
                value: timeValue,
                caption: estimate.sourceText,
                systemImage: "clock"
            ),
            UsageSummaryRow(
                title: "Last Charge",
                value: lastChargeSession.map { "\($0.percentage)%" } ?? "--",
                caption: lastChargeSession.map { "Reached \(dateText($0.date))" } ?? "No charging session in history yet",
                systemImage: "bolt.batteryblock"
            )
        ]
    }

    private func insights(
        range: BatteryUsageRange,
        snapshot: BatterySnapshot,
        topProcesses: [ProcessSample],
        batteryPoints: [BatteryHistoryPoint],
        screenBuckets: [ScreenUsageBucket],
        lastChargeSession: LastChargeSession?,
        dataSourceStatus: HistoryDataSourceStatus
    ) -> [UsageInsight] {
        var items: [UsageInsight] = [
            screenTimeInsight(range: range, screenBuckets: screenBuckets)
        ]

        if let lastChargeSession {
            items.append(
                UsageInsight(
                    title: "Last charge",
                    value: "\(lastChargeSession.percentage)%",
                    caption: dateText(lastChargeSession.date),
                    systemImage: "bolt.batteryblock",
                    kind: .positive
                )
            )
        }

        if let topProcess = topProcesses.first {
            items.append(
                UsageInsight(
                    title: "Top impact",
                    value: topProcess.name,
                    caption: "\(topProcess.usageText) right now",
                    systemImage: "flame",
                    kind: topProcess.energyImpact >= 50 ? .warning : .neutral
                )
            )
        }

        if let action = actionInsight(
            snapshot: snapshot,
            topProcess: topProcesses.first,
            batteryPoints: batteryPoints,
            dataSourceStatus: dataSourceStatus
        ) {
            items.append(action)
        }

        return Array(items.prefix(5))
    }

    private func screenTimeInsight(range: BatteryUsageRange, screenBuckets: [ScreenUsageBucket]) -> UsageInsight {
        let seconds = screenBuckets.reduce(0) { $0 + $1.activeSeconds }

        if seconds <= 0 {
            return UsageInsight(
                title: "Screen active",
                value: "--",
                caption: "Screen history starts when BatteryTime is running",
                systemImage: "display",
                kind: .neutral
            )
        }

        return UsageInsight(
            title: "Screen active",
            value: durationText(seconds: seconds),
            caption: "Across the \(range.title.lowercased())",
            systemImage: "display",
            kind: .neutral
        )
    }

    private func actionInsight(
        snapshot: BatterySnapshot,
        topProcess: ProcessSample?,
        batteryPoints: [BatteryHistoryPoint],
        dataSourceStatus: HistoryDataSourceStatus
    ) -> UsageInsight? {
        if let temperature = snapshot.temperatureCelsius, temperature >= 38 {
            return UsageInsight(
                title: "Action",
                value: "Cool down",
                caption: "Battery is running warm; reduce load or improve airflow.",
                systemImage: "thermometer.sun",
                kind: .action
            )
        }

        if let healthPercent = snapshot.healthPercent, healthPercent < 80 {
            return UsageInsight(
                title: "Action",
                value: "Check service",
                caption: "Maximum capacity is below 80%.",
                systemImage: "wrench.and.screwdriver",
                kind: .action
            )
        }

        if let percentage = snapshot.percentage, percentage <= 20, !snapshot.isPluggedIn {
            return UsageInsight(
                title: "Action",
                value: "Charge soon",
                caption: "Battery is low and the Mac is not connected to power.",
                systemImage: "battery.25percent",
                kind: .action
            )
        }

        if let topProcess, topProcess.energyImpact >= 50, !snapshot.isPluggedIn {
            return UsageInsight(
                title: "Action",
                value: "Reduce impact",
                caption: "\(topProcess.name) is the current highest energy user.",
                systemImage: "flame",
                kind: .action
            )
        }

        if dataSourceStatus.isFallback && batteryPoints.count < 8 {
            return UsageInsight(
                title: "Action",
                value: "Keep running",
                caption: "BatteryTime needs more samples to build useful history.",
                systemImage: "hourglass",
                kind: .action
            )
        }

        return nil
    }

    private func lastChargeSession(from points: [BatteryHistoryPoint]) -> LastChargeSession? {
        var sessionPoints: [BatteryHistoryPoint] = []

        for point in points.reversed() {
            if point.isPluggedIn || point.isCharging {
                sessionPoints.append(point)
                continue
            }

            if !sessionPoints.isEmpty {
                break
            }
        }

        guard let bestPoint = sessionPoints.max(by: { lhs, rhs in
            if lhs.percentage == rhs.percentage {
                return lhs.date < rhs.date
            }
            return lhs.percentage < rhs.percentage
        }) else {
            return nil
        }

        return LastChargeSession(
            percentage: bestPoint.percentage,
            date: bestPoint.date
        )
    }

    private func healthStatus(snapshot: BatterySnapshot) -> String {
        if let condition = snapshot.healthCondition, condition != "Good" {
            return condition
        }

        guard let healthPercent = snapshot.healthPercent else {
            return snapshot.healthCondition ?? "Unknown"
        }

        if healthPercent >= 90 {
            return "Good"
        }

        if healthPercent >= 80 {
            return "Reduced"
        }

        return "Service recommended"
    }

    private func healthGuidance(snapshot: BatterySnapshot) -> String {
        guard let healthPercent = snapshot.healthPercent else {
            return "Watch for changes"
        }

        if healthPercent >= 90 {
            return "No action needed"
        }

        if healthPercent >= 80 {
            return "Monitor capacity"
        }

        return "Plan service"
    }

    private func temperatureCaption(_ temperature: Double?) -> String {
        guard let temperature else {
            return "Temperature unavailable"
        }

        if temperature >= 38 {
            return "Warm enough to affect charging"
        }

        return "Normal operating range"
    }

    private func chargingCaption(snapshot: BatterySnapshot) -> String {
        if snapshot.isCharging {
            return "Battery is actively charging"
        }

        if snapshot.isPluggedIn {
            return "Connected, but not charging"
        }

        return "Running from battery"
    }

    private func durationText(seconds: TimeInterval) -> String {
        let minutes = max(0, Int(round(seconds / 60)))
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(remainingMinutes)m"
    }

    private func dateText(_ date: Date) -> String {
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

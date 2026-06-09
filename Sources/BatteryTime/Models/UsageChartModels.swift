import Foundation

struct UsageChartSelection<Value: Equatable>: Equatable {
    var hovered: Value?
    var pinned: Value?

    var primary: Value? {
        pinned ?? hovered
    }

    var preview: Value? {
        guard let pinned, let hovered, hovered != pinned else {
            return nil
        }

        return hovered
    }

    mutating func setHovered(_ value: Value?) {
        hovered = value
    }

    mutating func clearHover() {
        hovered = nil
    }

    mutating func pin(_ value: Value?) {
        pinned = value
    }

    mutating func clearPinned() {
        pinned = nil
    }
}

enum BatteryLevelBand: String, Equatable {
    case normal
    case watch
    case low
    case connected

    var title: String {
        switch self {
        case .normal:
            return "Normal"
        case .watch:
            return "Watch"
        case .low:
            return "Low"
        case .connected:
            return "Connected"
        }
    }
}

struct BatteryLevelChartPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let percentage: Int
    let isPluggedIn: Bool
    let isCharging: Bool
    let source: HistorySampleSource

    init(historyPoint: BatteryHistoryPoint) {
        self.id = historyPoint.id
        self.date = historyPoint.date
        self.percentage = historyPoint.percentage
        self.isPluggedIn = historyPoint.isPluggedIn
        self.isCharging = historyPoint.isCharging
        self.source = historyPoint.source
    }

    var band: BatteryLevelBand {
        if isPluggedIn || isCharging {
            return .connected
        }

        if percentage <= 20 {
            return .low
        }

        if percentage <= 40 {
            return .watch
        }

        return .normal
    }

    var powerStateText: String {
        if isCharging {
            return "Charging"
        }

        if isPluggedIn {
            return "Connected to power"
        }

        return "On battery"
    }
}

struct BatteryLevelChartSegment: Identifiable, Equatable {
    let id: String
    let points: [BatteryLevelChartPoint]
    let band: BatteryLevelBand

    static func segments(from points: [BatteryLevelChartPoint]) -> [BatteryLevelChartSegment] {
        guard points.count >= 2 else {
            return []
        }

        return zip(points, points.dropFirst()).enumerated().map { index, pair in
            BatteryLevelChartSegment(
                id: "\(index)-\(pair.0.id)-\(pair.1.id)",
                points: [pair.0, pair.1],
                band: pair.1.band
            )
        }
    }
}

struct ChargingInterval: Identifiable, Equatable {
    let id: String
    let startDate: Date
    let endDate: Date
    let isCharging: Bool

    static func intervals(
        from points: [BatteryLevelChartPoint],
        range: BatteryUsageRange,
        generatedAt: Date
    ) -> [ChargingInterval] {
        guard !points.isEmpty else {
            return []
        }

        let maxGap: TimeInterval = range == .day ? 30 * 60 : 24 * 60 * 60
        var intervals: [ChargingInterval] = []
        var startPoint: BatteryLevelChartPoint?
        var lastPoint: BatteryLevelChartPoint?
        var intervalIsCharging = false

        for point in points {
            if let lastPoint, point.date.timeIntervalSince(lastPoint.date) > maxGap {
                appendInterval(
                    startPoint: startPoint,
                    endPoint: lastPoint,
                    isCharging: intervalIsCharging,
                    into: &intervals
                )
                startPoint = nil
                intervalIsCharging = false
            }

            if point.isPluggedIn {
                if startPoint == nil {
                    startPoint = point
                    intervalIsCharging = point.isCharging
                } else {
                    intervalIsCharging = intervalIsCharging || point.isCharging
                }
            } else if let intervalStartPoint = startPoint, let lastPoint {
                appendInterval(
                    startPoint: intervalStartPoint,
                    endPoint: lastPoint,
                    isCharging: intervalIsCharging,
                    into: &intervals
                )
                startPoint = nil
                intervalIsCharging = false
            }

            lastPoint = point
        }

        if let startPoint, let lastPoint {
            appendInterval(
                startPoint: startPoint,
                endPoint: lastPoint,
                isCharging: intervalIsCharging,
                into: &intervals
            )
        }

        return intervals
    }

    private static func appendInterval(
        startPoint: BatteryLevelChartPoint?,
        endPoint: BatteryLevelChartPoint,
        isCharging: Bool,
        into intervals: inout [ChargingInterval]
    ) {
        guard let startPoint, endPoint.date > startPoint.date else {
            return
        }

        intervals.append(
            ChargingInterval(
                id: "\(startPoint.date.timeIntervalSince1970)-\(endPoint.date.timeIntervalSince1970)",
                startDate: startPoint.date,
                endDate: endPoint.date,
                isCharging: isCharging
            )
        )
    }

}

struct ScreenUsageChartBucket: Identifiable, Equatable {
    let id: String
    let startDate: Date
    let endDate: Date
    let activeSeconds: TimeInterval
    let source: HistorySampleSource

    init(bucket: ScreenUsageBucket) {
        self.id = bucket.id
        self.startDate = bucket.startDate
        self.endDate = bucket.endDate
        self.activeSeconds = bucket.activeSeconds
        self.source = bucket.source
    }

    var activeMinutes: Double {
        activeSeconds / 60
    }

    var midDate: Date {
        startDate.addingTimeInterval(endDate.timeIntervalSince(startDate) / 2)
    }

    var isNearZero: Bool {
        activeMinutes < 1
    }

    var xCategory: String {
        String(Int(startDate.timeIntervalSince1970))
    }
}

extension HistorySampleSource {
    var displayName: String {
        switch self {
        case .app:
            return "BatteryTime"
        case .powerlog:
            return "macOS history"
        }
    }
}

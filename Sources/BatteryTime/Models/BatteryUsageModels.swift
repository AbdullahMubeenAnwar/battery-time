import Foundation

enum BatteryUsageRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:   return "Day"
        case .week:  return "Week"
        case .month: return "Month"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .day:   return 24 * 60 * 60
        case .week:  return 7 * 24 * 60 * 60
        case .month: return 30 * 24 * 60 * 60
        }
    }

    var screenBucketInterval: TimeInterval {
        switch self {
        case .day:   return 60 * 60
        case .week:  return 24 * 60 * 60
        case .month: return 24 * 60 * 60
        }
    }

    var screenBucketUnitName: String {
        switch self {
        case .day:   return "hour"
        case .week:  return "day"
        case .month: return "day"
        }
    }

    func startDate(now: Date) -> Date {
        now.addingTimeInterval(-duration)
    }
}

enum HistorySampleSource: String, Equatable {
    case app
    case powerlog
}

struct BatteryHistoryPoint: Identifiable, Equatable {
    let date: Date
    let percentage: Int
    let isPluggedIn: Bool
    let isCharging: Bool
    let source: HistorySampleSource

    var id: String {
        "\(source.rawValue)-\(date.timeIntervalSince1970)-\(percentage)"
    }

    var isLow: Bool {
        percentage <= 20
    }
}

struct ScreenUsageBucket: Identifiable, Equatable {
    let startDate: Date
    let endDate: Date
    let activeSeconds: TimeInterval
    let source: HistorySampleSource

    var id: String {
        "\(source.rawValue)-\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)"
    }

    var activeMinutes: Double {
        activeSeconds / 60
    }
}

struct ScreenActivitySample: Equatable {
    let startDate: Date
    let endDate: Date
    let activeSeconds: TimeInterval
}

struct BatteryHistoryBackfill {
    let batteryPoints: [BatteryHistoryPoint]
    let screenBuckets: [ScreenUsageBucket]
}

struct PowerlogBackfillResult {
    let backfill: BatteryHistoryBackfill
    let isAvailable: Bool
    let reason: String?
}

struct HistoryDataSourceStatus: Equatable {
    let title: String
    let detail: String
    let isPowerlogAvailable: Bool
    let isFallback: Bool

    static func hybrid(batteryPoints: Int, screenBuckets: Int) -> HistoryDataSourceStatus {
        HistoryDataSourceStatus(
            title: "macOS history imported",
            detail: "\(batteryPoints) battery points and \(screenBuckets) screen-usage buckets are available from macOS power history.",
            isPowerlogAvailable: true,
            isFallback: false
        )
    }

    static func appOnly(reason: String, appBatteryPoints: Int) -> HistoryDataSourceStatus {
        let detail: String
        if appBatteryPoints > 0 {
            detail = "\(reason) BatteryTime has \(appBatteryPoints) app-collected battery samples."
        } else {
            detail = "\(reason) History starts when BatteryTime is running."
        }

        return HistoryDataSourceStatus(
            title: "BatteryTime history",
            detail: detail,
            isPowerlogAvailable: false,
            isFallback: true
        )
    }

    static var collecting: HistoryDataSourceStatus {
        HistoryDataSourceStatus(
            title: "Collecting history",
            detail: "History starts when BatteryTime is running.",
            isPowerlogAvailable: false,
            isFallback: true
        )
    }
}

enum UsageInsightKind: Equatable {
    case neutral
    case positive
    case warning
    case action
}

struct UsageInsight: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let value: String
    let caption: String
    let systemImage: String
    let kind: UsageInsightKind
}

struct UsageSummaryRow: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let value: String
    let caption: String
    let systemImage: String
}

struct LastChargeSession: Equatable {
    let percentage: Int
    let date: Date
}

struct BatteryUsageReport: Equatable {
    let range: BatteryUsageRange
    let generatedAt: Date
    let batteryPoints: [BatteryHistoryPoint]
    let screenBuckets: [ScreenUsageBucket]
    let insights: [UsageInsight]
    let healthRows: [UsageSummaryRow]
    let chargingRows: [UsageSummaryRow]
    let lastChargeSession: LastChargeSession?
    let dataSourceStatus: HistoryDataSourceStatus

    static func empty(range: BatteryUsageRange, now: Date = Date()) -> BatteryUsageReport {
        BatteryUsageReport(
            range: range,
            generatedAt: now,
            batteryPoints: [],
            screenBuckets: [],
            insights: [],
            healthRows: [],
            chargingRows: [],
            lastChargeSession: nil,
            dataSourceStatus: .collecting
        )
    }
}

struct BatteryHistoryCounts: Equatable {
    let appBatteryPoints: Int
    let powerlogBatteryPoints: Int
    let powerlogScreenBuckets: Int
}

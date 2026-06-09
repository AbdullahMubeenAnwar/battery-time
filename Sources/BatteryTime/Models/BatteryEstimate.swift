import Foundation

struct BatteryEstimate: Equatable {
    var minutes: Int?
    var systemMinutes: Int?
    var ratePercentPerHour: Double?
    var confidence: EstimateConfidence
    var windowMinutes: Int?

    var timeText: String? {
        minutes.map { DurationFormatter.batteryTime(minutes: $0) }
    }

    var rateText: String {
        guard let ratePercentPerHour else {
            return "Not enough data"
        }

        return String(format: "%.1f%% / hour", ratePercentPerHour)
    }

    var sourceText: String {
        if systemMinutes != nil {
            return "macOS estimate"
        }

        if let windowMinutes {
            return "\(windowMinutes)m rolling fallback"
        }

        return "Collecting samples"
    }
}

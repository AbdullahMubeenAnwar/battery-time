import Foundation

enum DurationFormatter {
    static func batteryTime(minutes: Int) -> String {
        let clampedMinutes = max(0, minutes)
        let hours = clampedMinutes / 60
        let remainingMinutes = clampedMinutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(remainingMinutes)m"
    }

    static func compactBatteryTime(minutes: Int) -> String {
        let clampedMinutes = max(0, minutes)
        let hours = clampedMinutes / 60
        let remainingMinutes = clampedMinutes % 60
        let paddedMinutes = remainingMinutes < 10 ? "0\(remainingMinutes)" : "\(remainingMinutes)"

        return "\(hours):\(paddedMinutes)"
    }

    static func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

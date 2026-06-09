import Foundation

enum BatteryDiagnosticsFormatter {
    static func percent(_ value: Int?) -> String {
        value.map { "\($0)%" } ?? "--"
    }

    static func minutes(_ value: Int?, calculatingWhenMissing: Bool = false) -> String {
        guard let value else {
            return calculatingWhenMissing ? "Calculating" : "--"
        }

        return DurationFormatter.batteryTime(minutes: value)
    }

    static func amperage(_ value: Int?) -> String {
        guard let value else {
            return "--"
        }

        return "\(abs(value)) mA"
    }

    static func voltage(_ millivolts: Int?) -> String {
        guard let millivolts else {
            return "--"
        }

        return String(format: "%.2f V", Double(millivolts) / 1000.0)
    }

    static func temperature(_ celsius: Double?) -> String {
        guard let celsius else {
            return "--"
        }

        return String(format: "%.2f C", celsius)
    }

    static func watts(_ watts: Double?, connected: Bool) -> String {
        guard connected else {
            return "Not connected"
        }

        guard let watts else {
            return "Connected"
        }

        return String(format: "%.0f W", watts)
    }

    static func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    static func integer(_ value: Int?) -> String {
        value.map(String.init) ?? "--"
    }
}

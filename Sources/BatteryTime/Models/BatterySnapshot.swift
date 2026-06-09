import Foundation

struct BatterySnapshot: Equatable {
    var isAvailable: Bool
    var sourceName: String
    var powerSource: String
    var percentage: Int?
    var currentCapacity: Int?
    var maxCapacity: Int?
    var nominalChargeCapacity: Int?
    var designCapacity: Int?
    var healthPercent: Int?
    var healthCondition: String?
    var cycleCount: Int?
    var amperageMilliamps: Int?
    var voltageMillivolts: Int?
    var temperatureCelsius: Double?
    var adapterConnected: Bool
    var adapterPowerWatts: Double?
    var isCharging: Bool
    var isPluggedIn: Bool
    var timeToEmptyMinutes: Int?
    var timeToFullMinutes: Int?
    var chargingLimitPercent: Int?
    var collectedAt: Date

    static var unavailable: BatterySnapshot {
        BatterySnapshot(
            isAvailable: false,
            sourceName: "Battery",
            powerSource: "Unknown",
            percentage: nil,
            currentCapacity: nil,
            maxCapacity: nil,
            nominalChargeCapacity: nil,
            designCapacity: nil,
            healthPercent: nil,
            healthCondition: nil,
            cycleCount: nil,
            amperageMilliamps: nil,
            voltageMillivolts: nil,
            temperatureCelsius: nil,
            adapterConnected: false,
            adapterPowerWatts: nil,
            isCharging: false,
            isPluggedIn: false,
            timeToEmptyMinutes: nil,
            timeToFullMinutes: nil,
            chargingLimitPercent: nil,
            collectedAt: Date()
        )
    }

    var displayMinutes: Int? {
        if isCharging {
            return timeToFullMinutes
        }

        if !isPluggedIn {
            return timeToEmptyMinutes
        }

        return nil
    }

    var stateTitle: String {
        if !isAvailable {
            return "Battery unavailable"
        }

        if isCharging {
            return "Charging"
        }

        if isPluggedIn {
            return "Connected to power"
        }

        return "On battery"
    }

    var timeCaption: String {
        if isCharging {
            return "until full"
        }

        if !isPluggedIn {
            return "remaining"
        }

        return "on power adapter"
    }

    var healthText: String {
        guard let healthPercent else {
            return "--"
        }

        if let healthCondition {
            return "\(healthPercent)% (\(healthCondition))"
        }

        return "\(healthPercent)%"
    }

    var symbolName: String {
        guard let percentage else {
            return "battery.0percent"
        }

        if isCharging {
            return "battery.100percent.bolt"
        }

        switch percentage {
        case 0..<25:
            return "battery.25percent"
        case 25..<60:
            return "battery.50percent"
        case 60..<85:
            return "battery.75percent"
        default:
            return "battery.100percent"
        }
    }
}

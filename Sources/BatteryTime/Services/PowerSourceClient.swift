import Foundation
import IOKit
import IOKit.ps

struct PowerSourceClient {
    func snapshot() -> BatterySnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [AnyObject],
              let details = firstBatteryDetails(info: info, sources: sources) else {
            return .unavailable
        }

        let registry = smartBatteryProperties() ?? [:]
        let maxCapacity = intValue(kIOPSMaxCapacityKey, in: details)
        let currentCapacity = intValue(kIOPSCurrentCapacityKey, in: details)
        let percentage = capacityPercent(current: currentCapacity, max: maxCapacity)
        let state = stringValue(kIOPSPowerSourceStateKey, in: details)
        let isPluggedIn = state == kIOPSACPowerValue as String
        let reportedIsCharging = boolValue(kIOPSIsChargingKey, in: details) ?? false
        let timeToEmpty = validMinutes(intValue(kIOPSTimeToEmptyKey, in: details))
        let timeToFull = validMinutes(intValue(kIOPSTimeToFullChargeKey, in: details))
        let nominalChargeCapacity = intValue("NominalChargeCapacity", in: registry)
            ?? intValue("AppleRawMaxCapacity", in: registry)
        let rawCurrentCapacity = intValue("AppleRawCurrentCapacity", in: registry)
        let designCapacity = intValue("DesignCapacity", in: registry)
            ?? dictionaryValue("BatteryData", in: registry).flatMap { intValue("DesignCapacity", in: $0) }
        let healthPercent = capacityPercent(current: nominalChargeCapacity, max: designCapacity)
        let permanentFailureStatus = intValue("PermanentFailureStatus", in: registry)
        let adapterConnected = boolValue("ExternalConnected", in: registry) ?? isPluggedIn
        let amperageMilliamps = intValue("Amperage", in: registry)
        let registryIsCharging = boolValue("IsCharging", in: registry) ?? false
        let effectiveIsCharging = reportedIsCharging
            || registryIsCharging
            || (adapterConnected && (amperageMilliamps ?? 0) > 0 && (percentage ?? 100) < 100)
        let effectiveIsPluggedIn = isPluggedIn || adapterConnected
        let registryTimeToFull = effectiveIsCharging
            ? validMinutes(intValue("AvgTimeToFull", in: registry))
                ?? validMinutes(intValue("TimeRemaining", in: registry))
            : nil
        let computedTimeToFull = computedTimeToFullMinutes(
            currentCapacity: rawCurrentCapacity,
            maxCapacity: nominalChargeCapacity,
            amperageMilliamps: amperageMilliamps,
            isCharging: effectiveIsCharging
        )

        return BatterySnapshot(
            isAvailable: true,
            sourceName: stringValue(kIOPSNameKey, in: details) ?? "Battery",
            powerSource: state ?? "Unknown",
            percentage: percentage,
            currentCapacity: currentCapacity,
            maxCapacity: maxCapacity,
            nominalChargeCapacity: nominalChargeCapacity,
            designCapacity: designCapacity,
            healthPercent: healthPercent,
            healthCondition: healthCondition(
                healthPercent: healthPercent,
                permanentFailureStatus: permanentFailureStatus
            ),
            cycleCount: intValue("CycleCount", in: registry),
            amperageMilliamps: amperageMilliamps,
            voltageMillivolts: intValue("Voltage", in: registry)
                ?? intValue("AppleRawBatteryVoltage", in: registry),
            temperatureCelsius: temperatureCelsius(in: registry),
            adapterConnected: adapterConnected,
            adapterPowerWatts: adapterPowerWatts(in: registry, isConnected: adapterConnected),
            isCharging: effectiveIsCharging,
            isPluggedIn: effectiveIsPluggedIn,
            timeToEmptyMinutes: timeToEmpty ?? fallbackTimeRemainingMinutes(isPluggedIn: effectiveIsPluggedIn),
            timeToFullMinutes: timeToFull ?? registryTimeToFull ?? computedTimeToFull,
            chargingLimitPercent: nil,
            collectedAt: Date()
        )
    }

    func calibratedHealth() -> ProfiledBatteryHealth? {
        profiledBatteryHealth()
    }

    func chargingLimitPercent() -> Int? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.batteryui.charging.mac.plist")
        guard let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let limit = dict["com.apple.batteryui.charging.mac.prior.limit"] as? Int,
              limit > 0, limit < 100 else {
            return nil
        }
        return limit
    }

    private func firstBatteryDetails(info: CFTypeRef, sources: [AnyObject]) -> [String: Any]? {
        let allDetails = sources.compactMap { source -> [String: Any]? in
            IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
        }

        return allDetails.first {
            stringValue(kIOPSTypeKey, in: $0) == kIOPSInternalBatteryType as String
        } ?? allDetails.first
    }

    private func capacityPercent(current: Int?, max maxCapacity: Int?) -> Int? {
        guard let current,
              let maxCapacity,
              maxCapacity > 0 else {
            return nil
        }

        return min(100, Swift.max(0, Int(round(Double(current) / Double(maxCapacity) * 100))))
    }

    private func fallbackTimeRemainingMinutes(isPluggedIn: Bool) -> Int? {
        guard !isPluggedIn else {
            return nil
        }

        let seconds = IOPSGetTimeRemainingEstimate()
        guard seconds > 0 else {
            return nil
        }

        return Int(seconds / 60)
    }

    private func computedTimeToFullMinutes(
        currentCapacity: Int?,
        maxCapacity: Int?,
        amperageMilliamps: Int?,
        isCharging: Bool
    ) -> Int? {
        guard isCharging,
              let currentCapacity,
              let maxCapacity,
              let amperageMilliamps,
              amperageMilliamps > 0,
              maxCapacity > currentCapacity else {
            return nil
        }

        let remainingMilliampHours = maxCapacity - currentCapacity
        return Int((Double(remainingMilliampHours) / Double(amperageMilliamps)) * 60)
    }

    private func smartBatteryProperties() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else {
            return nil
        }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(
            service,
            &properties,
            kCFAllocatorDefault,
            0
        )

        guard result == KERN_SUCCESS,
              let dictionary = properties?.takeRetainedValue() as NSDictionary? else {
            return nil
        }

        return dictionary as? [String: Any]
    }

    // Throttling and caching live in BatteryMonitor; this always performs the fetch.
    private func profiledBatteryHealth() -> ProfiledBatteryHealth? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPPowerDataType", "-json"]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        let sema = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in sema.signal() }

        do {
            try process.run()
        } catch {
            return nil
        }

        guard sema.wait(timeout: .now() + 8) != .timedOut else {
            process.terminate()
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        return parseProfiledBatteryHealth(data: data)
    }

    private func parseProfiledBatteryHealth(data: Data) -> ProfiledBatteryHealth? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["SPPowerDataType"] as? [[String: Any]],
              let batteryInfo = items.first(where: { $0["_name"] as? String == "spbattery_information" }),
              let healthInfo = batteryInfo["sppower_battery_health_info"] as? [String: Any] else {
            return nil
        }

        return ProfiledBatteryHealth(
            maximumCapacityPercent: maximumCapacityPercent(from: healthInfo["sppower_battery_health_maximum_capacity"]),
            condition: healthInfo["sppower_battery_health"] as? String,
            cycleCount: intValue("sppower_battery_cycle_count", in: healthInfo)
        )
    }

    private func maximumCapacityPercent(from value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }

        if let value = value as? NSNumber {
            return value.intValue
        }

        if let value = value as? String {
            let digits = value.filter(\.isNumber)
            return Int(digits)
        }

        return nil
    }

    private func healthCondition(healthPercent: Int?, permanentFailureStatus: Int?) -> String? {
        if let permanentFailureStatus, permanentFailureStatus > 0 {
            return "Service"
        }

        guard let healthPercent else {
            return nil
        }

        if healthPercent >= 90 {
            return "Good"
        }

        if healthPercent >= 80 {
            return "Fair"
        }

        return "Service"
    }

    private func temperatureCelsius(in details: [String: Any]) -> Double? {
        guard let rawTemperature = intValue("Temperature", in: details)
            ?? intValue("VirtualTemperature", in: details) else {
            return nil
        }

        return Double(rawTemperature) / 100.0
    }

    private func adapterPowerWatts(in details: [String: Any], isConnected: Bool) -> Double? {
        guard isConnected else {
            return nil
        }

        if let adapterDetails = dictionaryValue("AdapterDetails", in: details) {
            return doubleValue("Watts", in: adapterDetails)
                ?? doubleValue("AdapterPower", in: adapterDetails)
        }

        return nil
    }

    private func validMinutes(_ minutes: Int?) -> Int? {
        guard let minutes, minutes > 0, minutes < 65535 else {
            return nil
        }

        return minutes
    }

    private func stringValue(_ key: String, in details: [String: Any]) -> String? {
        details[key] as? String
    }

    private func dictionaryValue(_ key: String, in details: [String: Any]) -> [String: Any]? {
        if let value = details[key] as? [String: Any] {
            return value
        }

        if let value = details[key] as? NSDictionary {
            return value as? [String: Any]
        }

        return nil
    }

    private func intValue(_ key: String, in details: [String: Any]) -> Int? {
        if let value = details[key] as? Int {
            return value
        }

        if let value = details[key] as? NSNumber {
            return value.intValue
        }

        return nil
    }

    private func boolValue(_ key: String, in details: [String: Any]) -> Bool? {
        if let value = details[key] as? Bool {
            return value
        }

        if let value = details[key] as? NSNumber {
            return value.boolValue
        }

        return nil
    }

    private func doubleValue(_ key: String, in details: [String: Any]) -> Double? {
        if let value = details[key] as? Double {
            return value
        }

        if let value = details[key] as? Int {
            return Double(value)
        }

        if let value = details[key] as? NSNumber {
            return value.doubleValue
        }

        return nil
    }
}

struct ProfiledBatteryHealth {
    let maximumCapacityPercent: Int?
    let condition: String?
    let cycleCount: Int?
}

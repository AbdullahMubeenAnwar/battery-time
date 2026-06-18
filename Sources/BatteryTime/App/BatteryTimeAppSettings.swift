import AppKit
import Foundation
import ServiceManagement

enum BatteryTimeAppSettings {
    static let showDockIconKey = "showDockIcon"
    static let menuBarDisplayFormatKey = "menuBarDisplayFormat"
    static let colorizeBatteryKey = "colorizeBattery"
    static let xlBatterySizeKey = "xlBatterySize"
    static let chargerStateInsideBatteryKey = "chargerStateInsideBattery"
    static let hideAdditionalWhenFullKey = "hideAdditionalWhenFull"

    // Popover — sections
    static let popoverShowDetailsKey        = "popoverShowDetails"
    static let popoverShowTopProcessKey     = "popoverShowTopProcess"
    static let popoverShowUptimeKey         = "popoverShowUptime"

    // Popover — layout
    static let popoverCompactKey            = "popoverCompact"

    // Popover — individual detail rows
    static let popoverShowChargeKey         = "popoverShowCharge"
    static let popoverShowTimeRemainingKey  = "popoverShowTimeRemaining"
    static let popoverShowDrainRateKey      = "popoverShowDrainRate"
    static let popoverShowCapacityKey       = "popoverShowCapacity"
    static let popoverShowTemperatureKey    = "popoverShowTemperature"
    static let popoverShowEstimateSourceKey = "popoverShowEstimateSource"
    static let popoverShowChargeLimitKey    = "popoverShowChargeLimit"
    static let popoverShowDrainStatusKey    = "popoverShowDrainStatus"

    static let defaultShowDockIcon = false
    static let defaultMenuBarDisplayFormat = DisplayFormat.iconOnly
    static let defaultColorizeBattery = true
    static let defaultXLBatterySize = false
    static let defaultChargerStateInsideBattery = true
    static let defaultHideAdditionalWhenFull = true
    static let defaultLaunchAtLoginEnabled = false

    // Popover defaults
    static let defaultPopoverShowDetails        = true
    static let defaultPopoverShowTopProcess     = true
    static let defaultPopoverShowUptime         = true
    static let defaultPopoverCompact            = false
    static let defaultPopoverShowCharge         = true
    static let defaultPopoverShowTimeRemaining  = true
    static let defaultPopoverShowDrainRate      = true
    static let defaultPopoverShowCapacity       = true
    static let defaultPopoverShowTemperature    = true
    static let defaultPopoverShowEstimateSource = false
    static let defaultPopoverShowChargeLimit    = true
    static let defaultPopoverShowDrainStatus    = true

    private static let launchAtLoginInitializedKey = "launchAtLoginInitialized"

    static func initializeDefaults() {
        UserDefaults.standard.register(defaults: [
            showDockIconKey: defaultShowDockIcon,
            menuBarDisplayFormatKey: defaultMenuBarDisplayFormat.rawValue,
            colorizeBatteryKey: defaultColorizeBattery,
            xlBatterySizeKey: defaultXLBatterySize,
            chargerStateInsideBatteryKey: defaultChargerStateInsideBattery,
            hideAdditionalWhenFullKey: defaultHideAdditionalWhenFull,
            // Popover
            popoverShowDetailsKey: defaultPopoverShowDetails,
            popoverShowTopProcessKey: defaultPopoverShowTopProcess,
            popoverShowUptimeKey: defaultPopoverShowUptime,
            popoverCompactKey: defaultPopoverCompact,
            popoverShowChargeKey: defaultPopoverShowCharge,
            popoverShowTimeRemainingKey: defaultPopoverShowTimeRemaining,
            popoverShowDrainRateKey: defaultPopoverShowDrainRate,
            popoverShowCapacityKey: defaultPopoverShowCapacity,
            popoverShowTemperatureKey: defaultPopoverShowTemperature,
            popoverShowEstimateSourceKey: defaultPopoverShowEstimateSource,
            popoverShowChargeLimitKey: defaultPopoverShowChargeLimit,
            popoverShowDrainStatusKey: defaultPopoverShowDrainStatus
        ])

        guard UserDefaults.standard.object(forKey: launchAtLoginInitializedKey) == nil else {
            return
        }

        UserDefaults.standard.set(true, forKey: launchAtLoginInitializedKey)

        if defaultLaunchAtLoginEnabled {
            try? updateLaunchAtLoginEnabled(true)
        }
    }

    static var showDockIcon: Bool {
        UserDefaults.standard.object(forKey: showDockIconKey) as? Bool ?? defaultShowDockIcon
    }

    static var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var launchAtLoginRequiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    @MainActor
    static func applyDockIconVisibility(show: Bool = showDockIcon, activate: Bool = false) {
        NSApp.setActivationPolicy(show ? .regular : .accessory)

        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    static func setLaunchAtLoginEnabled(_ enabled: Bool) throws {
        try updateLaunchAtLoginEnabled(enabled)
        UserDefaults.standard.set(true, forKey: launchAtLoginInitializedKey)
    }

    private static func updateLaunchAtLoginEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp

        if enabled {
            if service.status == .enabled {
                try? service.unregister()
            }

            try service.register()
        } else {
            guard service.status != .notRegistered else {
                return
            }

            try service.unregister()
        }
    }
}

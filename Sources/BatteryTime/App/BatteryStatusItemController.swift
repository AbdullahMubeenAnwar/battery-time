import AppKit
import Combine
import SwiftUI

final class BatteryStatusItemController: NSObject {
    private let batteryMonitor: BatteryMonitor
    private let openMainWindow: () -> Void
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables: Set<AnyCancellable> = []

    init(batteryMonitor: BatteryMonitor, openMainWindow: @escaping () -> Void) {
        self.batteryMonitor = batteryMonitor
        self.openMainWindow = openMainWindow
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()

        super.init()

        configureStatusButton()
        configurePopover()
        bindUpdates()
        updateStatusButton()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.toolTip = "Battery Time"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 300, height: 412)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarBatteryView(openMainWindow: { [weak self] in
                self?.popover.performClose(nil)
                self?.openMainWindow()
            })
            .environmentObject(batteryMonitor)
            .frame(width: 300)
        )
    }

    private func bindUpdates() {
        batteryMonitor.$snapshot
            .combineLatest(batteryMonitor.$estimate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusButton()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusButton()
            }
            .store(in: &cancellables)
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        let displayFormat = currentDisplayFormat()
        let hideWhenFull = boolSetting(
            key: BatteryTimeAppSettings.hideAdditionalWhenFullKey,
            defaultValue: BatteryTimeAppSettings.defaultHideAdditionalWhenFull
        )
        let title = batteryMonitor.menuBarTitle(format: displayFormat, hideWhenFull: hideWhenFull)
        let spokenTitle = title.isEmpty ? "Battery Time" : "Battery Time, \(title.replacingOccurrences(of: "\n", with: ", "))"
        let chargerInside = boolSetting(
            key: BatteryTimeAppSettings.chargerStateInsideBatteryKey,
            defaultValue: BatteryTimeAppSettings.defaultChargerStateInsideBattery
        )
        let showsInnerPercentage = displayFormat == .innerPercentage
            && (!batteryMonitor.snapshot.isPluggedIn || !chargerInside)

        button.attributedTitle = NSAttributedString(string: "")
        button.image = BatteryStatusIconRenderer.image(
            for: batteryMonitor.snapshot,
            title: title,
            showsInnerPercentage: showsInnerPercentage,
            colorize: boolSetting(
                key: BatteryTimeAppSettings.colorizeBatteryKey,
                defaultValue: BatteryTimeAppSettings.defaultColorizeBattery
            ),
            xlSize: boolSetting(
                key: BatteryTimeAppSettings.xlBatterySizeKey,
                defaultValue: BatteryTimeAppSettings.defaultXLBatterySize
            ),
            chargerInside: chargerInside
        )
        button.toolTip = spokenTitle
        button.setAccessibilityLabel(spokenTitle)
        statusItem.length = NSStatusItem.variableLength
    }

    private func currentDisplayFormat() -> DisplayFormat {
        let savedFormat = DisplayFormat(
            rawValue: UserDefaults.standard.string(forKey: BatteryTimeAppSettings.menuBarDisplayFormatKey)
                ?? BatteryTimeAppSettings.defaultMenuBarDisplayFormat.rawValue
        ) ?? BatteryTimeAppSettings.defaultMenuBarDisplayFormat
        return savedFormat
    }

    private func boolSetting(key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }

        return UserDefaults.standard.bool(forKey: key)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

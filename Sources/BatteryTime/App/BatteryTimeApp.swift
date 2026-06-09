import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        BatteryTimeAppSettings.initializeDefaults()
        BatteryTimeAppSettings.applyDockIconVisibility(
            show: BatteryTimeAppSettings.showDockIcon,
            activate: BatteryTimeAppSettings.showDockIcon
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: BatteryTimeAppModel.showMainWindowNotification, object: nil)
        }

        return true
    }
}

@main
struct BatteryTimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = BatteryTimeAppModel()

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appModel.batteryMonitor)
        }
        .commands {
            CommandMenu("Battery") {
                Button("Refresh") {
                    appModel.batteryMonitor.refresh()
                }
                .keyboardShortcut("r")

                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(
                        name: BatteryTimeAppModel.toggleSidebarNotification,
                        object: nil
                    )
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }
        }
    }
}

import AppKit
import Foundation
import SwiftUI

@MainActor
final class BatteryTimeAppModel: ObservableObject {
    static let showMainWindowNotification = Notification.Name("BatteryTimeShowMainWindow")

    let batteryMonitor: BatteryMonitor
    private let mainWindowController: MainWindowController
    private let statusItemController: BatteryStatusItemController
    // Touched only on the main thread (init and deinit); marked unsafe so the
    // nonisolated deinit can remove them.
    private nonisolated(unsafe) var launchObserver: NSObjectProtocol?
    private nonisolated(unsafe) var showWindowObserver: NSObjectProtocol?
    private var settingsWindowController: NSWindowController?

    init() {
        let batteryMonitor = BatteryMonitor()

        // Use a box so we can fill in the real closure after self is initialized.
        var openSettingsImpl: (() -> Void)?
        let mainWindowController = MainWindowController(
            batteryMonitor: batteryMonitor,
            openSettings: { openSettingsImpl?() }
        )

        self.batteryMonitor = batteryMonitor
        self.mainWindowController = mainWindowController
        self.statusItemController = BatteryStatusItemController(
            batteryMonitor: batteryMonitor,
            openMainWindow: {
                mainWindowController.show()
            }
        )

        self.launchObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                MainActor.assumeIsolated {
                    mainWindowController.show()
                }
            }
        }

        self.showWindowObserver = NotificationCenter.default.addObserver(
            forName: Self.showMainWindowNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Delivered on the main queue per the observer's queue parameter.
            MainActor.assumeIsolated {
                mainWindowController.show()
            }
        }

        // All stored properties initialized — self is available now.
        openSettingsImpl = { [weak self] in self?.showSettings() }
    }

    private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if let wc = settingsWindowController {
            wc.showWindow(nil)
            return
        }
        let view = SettingsView().environmentObject(batteryMonitor)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        let wc = NSWindowController(window: window)
        settingsWindowController = wc
        wc.showWindow(nil)
    }

    deinit {
        if let launchObserver {
            NotificationCenter.default.removeObserver(launchObserver)
        }

        if let showWindowObserver {
            NotificationCenter.default.removeObserver(showWindowObserver)
        }
    }
}

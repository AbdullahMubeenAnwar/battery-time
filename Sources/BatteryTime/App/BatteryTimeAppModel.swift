import AppKit
import Foundation

final class BatteryTimeAppModel: ObservableObject {
    static let showMainWindowNotification = Notification.Name("BatteryTimeShowMainWindow")
    static let toggleSidebarNotification = Notification.Name("BatteryTimeToggleSidebar")

    let batteryMonitor: BatteryMonitor
    private let mainWindowController: MainWindowController
    private let statusItemController: BatteryStatusItemController
    private var launchObserver: NSObjectProtocol?
    private var showWindowObserver: NSObjectProtocol?

    init() {
        let batteryMonitor = BatteryMonitor()
        let mainWindowController = MainWindowController(batteryMonitor: batteryMonitor)

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
                mainWindowController.show()
            }
        }

        self.showWindowObserver = NotificationCenter.default.addObserver(
            forName: Self.showMainWindowNotification,
            object: nil,
            queue: .main
        ) { _ in
            mainWindowController.show()
        }
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

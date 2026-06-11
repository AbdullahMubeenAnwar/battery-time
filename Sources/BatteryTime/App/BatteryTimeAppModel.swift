import AppKit
import Foundation

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

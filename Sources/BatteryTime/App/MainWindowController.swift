import AppKit
import SwiftUI

@MainActor
final class MainWindowController {
    private let batteryMonitor: BatteryMonitor
    private var window: NSWindow?

    init(batteryMonitor: BatteryMonitor) {
        self.batteryMonitor = batteryMonitor
    }

    func show() {
        if let existingWindow = existingMainWindow() {
            window = existingWindow
            present(existingWindow)
            return
        }

        if let window {
            present(window)
            return
        }

        let contentView = ContentView()
            .environmentObject(batteryMonitor)
            .frame(minWidth: 760, minHeight: 480)

        let window = NSWindow(
            contentRect: initialFrame(),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.styleMask.insert(.fullSizeContentView)
        window.title = "Battery Time"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.identifier = NSUserInterfaceItemIdentifier("BatteryTimeMainWindow")
        window.minSize = NSSize(width: 760, height: 480)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.isMovableByWindowBackground = true
        window.contentViewController = NSHostingController(rootView: contentView)
        window.setFrame(initialFrame(), display: false)

        self.window = window
        present(window)
    }

    private func present(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func existingMainWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.canBecomeMain &&
                (window.identifier?.rawValue == "BatteryTimeMainWindow" ||
                 ["Overview", "Usage", "Battery Time"].contains(window.title))
        }
    }

    private func initialFrame() -> NSRect {
        let size = NSSize(width: 920, height: 713)
        guard let visibleFrame = NSScreen.main?.visibleFrame else {
            return NSRect(origin: .zero, size: size)
        }

        return NSRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

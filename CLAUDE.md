# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
./script/build_and_run.sh          # build and launch the app
./script/build_and_run.sh debug    # build and attach lldb
./script/build_and_run.sh logs     # launch and stream os_log output
./script/build_and_run.sh verify   # launch and wait to confirm it started
```

The script first tries `swift build` (enabled by setting `BATTERYTIME_USE_SWIFTPM=1`); otherwise it falls back to a direct `swiftc` invocation targeting macOS 26.0. It kills any running instance before each build, assembles `dist/BatteryTime.app`, writes `Info.plist`, and ad-hoc codesigns the bundle.

There are no tests.

## Architecture

The app is a menu bar app with a secondary main window. `BatteryTimeAppModel` is the root object created at launch; it owns `BatteryMonitor`, `MainWindowController`, and `BatteryStatusItemController`.

**Data flow (unidirectional):**
1. `PowerSourceClient` reads live data from IOKit
2. `BatteryMonitor` (ObservableObject) polls every 60 s and also subscribes to `IOPSNotificationCreateRunLoopSource` for instant power-source changes; it owns all service objects and publishes `snapshot`, `estimate`, `samples`, `topProcesses`, and `usageReport`
3. Views observe `BatteryMonitor` via `@EnvironmentObject`

**Services layer (`Sources/BatteryTime/Services/`):**
- `BatteryEstimator` — computes time remaining using 10/30/60-minute rolling drain/charge rates; falls back to the system estimate when its own rates are unavailable
- `BatteryHistoryStore` — SQLite3 persistence (`~/Library/Application Support/BatteryTime/BatteryHistory.sqlite3`); stores `battery_samples` and `screen_usage`; retains 30 days; handles powerlog backfill via `INSERT OR REPLACE`
- `PowerlogBackfillClient` — imports macOS system power history (`powerlog`) on a background thread once per hour to enrich charts beyond what the app has observed itself
- `ProcessSampler` — samples top energy-consuming processes on a background thread
- `ScreenActivityMonitor` — tracks screen-on time in minute-resolution buckets
- `BatteryUsageAnalyzer` — synthesises all sources into a `BatteryUsageReport` for the charts/UI

**UI surface points:**
- Menu bar icon/popover — `BatteryStatusItemController` renders a custom `NSImage` via `BatteryStatusIconRenderer` and hosts `MenuBarBatteryView` in an `NSPopover`
- Main window — `MainWindowController` (NSWindow subclass) hosts `ContentView`
- Settings — standard SwiftUI `Settings` scene hosts `SettingsView`

**Frameworks linked:** SwiftUI, Charts, AppKit, IOKit, ServiceManagement, sqlite3 (no third-party dependencies).

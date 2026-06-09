<div align="center">

# 🔋 Battery Time

**A fast, native macOS menu bar app for real-time battery monitoring**

[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-000000?style=flat-square&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-0A84FF?style=flat-square)](LICENSE)
[![Releases](https://img.shields.io/github/v/release/abdullahubeen/battery-time?style=flat-square&color=34C759)](https://github.com/abdullahubeen/battery-time/releases/latest)

[**Download DMG**](#-install) · [Build from source](#-build-from-source) · [Features](#-features)

---

![Battery Time screenshot](Assets/screenshot.png)

</div>

---

## ✨ Features

| | |
|---|---|
| 🔋 **Menu bar widget** | Battery icon with %, time remaining, or both — 6 display modes |
| 📊 **30-day history** | SQLite-backed battery history with automatic macOS powerlog backfill |
| 📈 **Usage charts** | Day / week / month battery level charts with power-connection overlay |
| ⚡️ **Smart estimates** | Rolling 10 / 30 / 60-min drain rates; falls back to macOS system estimate |
| 🖥 **Screen time tracking** | Minute-resolution screen-active time, charted alongside battery |
| ❤️ **Health & diagnostics** | Cycle count, max capacity %, temperature, adapter wattage |
| 🔥 **Top energy processes** | Which apps are draining the most right now |
| 🎨 **Colorized icon** | Green / orange / red battery fill, optional XL size |
| 🚀 **Launch at login** | Stays in the background keeping history complete |

---

## 📦 Install

### Option 1 — Download DMG *(recommended)*

1. Open the [**latest release**](https://github.com/abdullahubeen/battery-time/releases/latest)
2. Download `BatteryTime-x.x.dmg`
3. Open the DMG, drag **Battery Time** → **Applications**
4. Launch it — the battery icon appears in your menu bar

> **Requires macOS 26 (Tahoe) or later.**

### Option 2 — Homebrew Cask *(coming soon)*

```bash
brew install --cask battery-time
```

---

## 🔨 Build from source

**Requirements:** macOS 26+, Xcode 17+

```bash
# Clone
git clone https://github.com/abdullahubeen/battery-time.git
cd battery-time

# Build and launch
./script/build_and_run.sh

# Or build a release DMG (output: release/BatteryTime-x.x.dmg)
./script/build_dmg.sh
```

Additional build modes:

```bash
./script/build_and_run.sh debug    # build + attach lldb
./script/build_and_run.sh logs     # launch + stream os_log output
./script/build_and_run.sh verify   # launch + confirm it started
```

---

## 🏗 Architecture

Battery Time is a pure Swift / SwiftUI / AppKit app — **zero third-party dependencies**.

```
BatteryTimeAppModel          ← root object, owns everything
├── BatteryMonitor            ← ObservableObject, polls IOKit every 60 s
│   ├── PowerSourceClient     ← reads live data from IOKit
│   ├── BatteryEstimator      ← rolling 10/30/60-min drain/charge rates
│   ├── BatteryHistoryStore   ← SQLite3 persistence (30-day retention, WAL mode)
│   ├── PowerlogBackfillClient← imports macOS powerlog history once/hr
│   ├── ProcessSampler        ← top energy-consuming processes
│   ├── ScreenActivityMonitor ← screen-on time in minute buckets
│   └── BatteryUsageAnalyzer  ← synthesises all sources into BatteryUsageReport
├── BatteryStatusItemController ← menu bar icon + popover
└── MainWindowController      ← main window (Overview + Usage tabs)
```

**Frameworks:** SwiftUI · Charts · AppKit · IOKit · ServiceManagement · sqlite3

---

## 🤝 Contributing

Pull requests welcome. Please open an issue first to discuss major changes.

```bash
git clone https://github.com/abdullahubeen/battery-time.git
cd battery-time
./script/build_and_run.sh   # build + run
```

---

## 📄 License

[MIT](LICENSE) © Abdullah Mubeen

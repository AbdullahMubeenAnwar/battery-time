// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "BatteryTime",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "BatteryTime", targets: ["BatteryTime"])
    ],
    targets: [
        .executableTarget(
            name: "BatteryTime",
            linkerSettings: [
                .linkedFramework("Charts"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)

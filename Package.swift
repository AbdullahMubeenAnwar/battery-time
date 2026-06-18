// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "BatteryTime",
    platforms: [
        .macOS("13.0")
    ],
    products: [
        .executable(name: "BatteryTime", targets: ["BatteryTime"])
    ],
    targets: [
        .executableTarget(
            name: "BatteryTime",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)

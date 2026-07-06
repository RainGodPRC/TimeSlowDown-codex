// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TimeSlowDownNative",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TimeSlowDownKit",
            targets: ["TimeSlowDownKit"]
        ),
        .executable(
            name: "TimeSlowDownNativeChecks",
            targets: ["TimeSlowDownNativeChecks"]
        )
    ],
    targets: [
        .target(
            name: "TimeSlowDownKit"
        ),
        .executableTarget(
            name: "TimeSlowDownNativeChecks",
            dependencies: ["TimeSlowDownKit"]
        )
    ]
)

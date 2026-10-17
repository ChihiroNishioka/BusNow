// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BusNowCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "BusNowCore", targets: ["BusNowCore"]),
    ],
    targets: [
        .target(
            name: "BusNowCore",
            path: "Sources/BusNowCore",
            resources: [
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "BusNowCoreTests",
            dependencies: ["BusNowCore"],
            path: "Tests/BusNowCoreTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)

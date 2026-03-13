// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mon",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MonitorKit", targets: ["MonitorKit"]),
        .executable(name: "mon", targets: ["mon"]),
        .executable(name: "MonApp", targets: ["MonitorApp"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MonitorKit",
            dependencies: [],
            path: "Sources/MonitorKit"
        ),
        .executableTarget(
            name: "mon",
            dependencies: ["MonitorKit"],
            path: "Sources/mon"
        ),
        .executableTarget(
            name: "MonitorApp",
            dependencies: ["MonitorKit"],
            path: "Sources/MonitorApp"
        ),
    ]
)

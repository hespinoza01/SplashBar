// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SplashBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SplashBar",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
    ]
)

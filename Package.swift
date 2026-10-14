// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Screenshoti",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Screenshoti", targets: ["Screenshoti"])
    ],
    targets: [
        .executableTarget(
            name: "Screenshoti",
            path: "Sources/Screenshoti",
            resources: [
                .process("Resources")
            ]
        )
    ]
)

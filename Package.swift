// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JianTie",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "JianTieCore",
            targets: ["JianTieCore"]
        ),
        .executable(
            name: "JianTie",
            targets: ["JianTieApp"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "JianTieCore",
            dependencies: []
        ),
        .executableTarget(
            name: "JianTieApp",
            dependencies: ["JianTieCore"],
            exclude: ["Info.plist"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "JianTieTests",
            dependencies: ["JianTieCore", "JianTieApp"]
        )
    ]
)

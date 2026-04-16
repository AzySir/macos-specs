// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MacOSSpecs",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacOSSpecs", targets: ["MacOSSpecs"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MacOSSpecs",
            path: "Sources/MacOSSpecs"
        ),
    ]
)

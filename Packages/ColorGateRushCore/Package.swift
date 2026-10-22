// swift-tools-version:5.9
import PackageDescription

// Platform-independent game rules for Color Gate Rush.
// The iOS app compiles these sources directly into its target (see project.yml);
// this package exists so the rules can be unit-tested with `swift test` on macOS or Linux.
let package = Package(
    name: "ColorGateRushCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ColorGateRushCore", targets: ["ColorGateRushCore"])
    ],
    targets: [
        .target(name: "ColorGateRushCore"),
        .testTarget(name: "ColorGateRushCoreTests", dependencies: ["ColorGateRushCore"])
    ]
)

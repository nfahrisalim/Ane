// swift-tools-version: 6.0
import PackageDescription

// The rhythm core lives in `Ane/Rhythm` so the iOS app target compiles it directly
// through its synchronized folder, while this package lets `swift test` exercise the
// same sources on the host machine with no simulator and no audio hardware.
let package = Package(
    name: "RhythmKit",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "RhythmKit", targets: ["RhythmKit"])
    ],
    targets: [
        .target(
            name: "RhythmKit",
            path: "Ane/Rhythm",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "RhythmKitTests",
            dependencies: ["RhythmKit"],
            path: "Tests/RhythmKitTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)

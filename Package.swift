// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Gridline",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Gridline", targets: ["Gridline"]),
    ],
    targets: [
        // Pure Swift: Datenmodell, Timing, Projektformat. Keine Apple-Frameworks außer Foundation.
        .target(name: "GridlineCore"),
        // Echtzeit-Audio: Sample-Stimmen, Renderer, AVAudioEngine-Anbindung.
        .target(name: "GridlineAudio", dependencies: ["GridlineCore"]),
        // SwiftUI-App.
        .executableTarget(name: "Gridline", dependencies: ["GridlineCore", "GridlineAudio"]),
        .testTarget(name: "GridlineCoreTests", dependencies: ["GridlineCore"]),
        .testTarget(name: "GridlineAudioTests", dependencies: ["GridlineAudio", "GridlineCore"]),
    ]
)

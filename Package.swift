// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Gridline",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .executable(name: "Gridline", targets: ["Gridline"]),
        .library(name: "GridlineUI", targets: ["GridlineUI"]),
    ],
    targets: [
        // Pure Swift: Datenmodell, Timing, Projektformat. Keine Apple-Frameworks außer Foundation.
        .target(name: "GridlineCore"),
        // Echtzeit-Audio: Sample-Stimmen, Renderer, AVAudioEngine-Anbindung.
        .target(name: "GridlineAudio", dependencies: ["GridlineCore"]),
        // Gemeinsame SwiftUI-Oberfläche für macOS, iOS und iPadOS.
        .target(name: "GridlineUI", dependencies: ["GridlineCore", "GridlineAudio"]),
        // macOS-App. Die iOS/iPadOS-App liegt als XcodeGen-Projekt unter `iOS/`.
        .executableTarget(name: "Gridline", dependencies: ["GridlineUI"]),
        .testTarget(name: "GridlineCoreTests", dependencies: ["GridlineCore"]),
        .testTarget(name: "GridlineAudioTests", dependencies: ["GridlineAudio", "GridlineCore"]),
    ]
)

// swift-tools-version:5.10
import PackageDescription

// Plattformneutraler Kern: läuft auf macOS, iOS und Linux.
var products: [Product] = []
var targets: [Target] = [
    // Pure Swift: Datenmodell, Timing, Projektformat. Nur Foundation.
    .target(name: "GridlineCore"),
    // Sequencer, Stimmen, Renderer, WAV-Import. AVAudioEngine nur auf Apple-Plattformen.
    .target(name: "GridlineAudio", dependencies: ["GridlineCore"]),
    .testTarget(name: "GridlineCoreTests", dependencies: ["GridlineCore"]),
    .testTarget(name: "GridlineAudioTests", dependencies: ["GridlineAudio", "GridlineCore"]),
]

#if !os(Linux)
// Apple-Oberflächen. Die iOS/iPadOS-App liegt als XcodeGen-Projekt unter `iOS/`.
products += [
    .executable(name: "Gridline", targets: ["Gridline"]),
    .library(name: "GridlineUI", targets: ["GridlineUI"]),
]
targets += [
    // Gemeinsame SwiftUI-Oberfläche für macOS, iOS und iPadOS.
    .target(name: "GridlineUI", dependencies: ["GridlineCore", "GridlineAudio"]),
    // macOS-App.
    .executableTarget(name: "Gridline", dependencies: ["GridlineUI"]),
]
#endif

let package = Package(
    name: "Gridline",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: products,
    targets: targets
)

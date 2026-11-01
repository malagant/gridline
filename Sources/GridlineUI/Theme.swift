import SwiftUI

/// Eigenes Farbschema von Gridline: dunkles Tintenblau mit Mint-Akzent.
enum Theme {
    static let background = Color(red: 0.07, green: 0.08, blue: 0.10)
    static let panel = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let beatRow = Color(red: 0.12, green: 0.13, blue: 0.17)
    static let barRow = Color(red: 0.15, green: 0.16, blue: 0.21)
    static let accent = Color(red: 0.36, green: 0.88, blue: 0.71)
    static let playhead = Color(red: 0.36, green: 0.88, blue: 0.71).opacity(0.22)
    static let cursor = Color(red: 0.98, green: 0.73, blue: 0.29)
    static let text = Color(white: 0.86)
    static let dim = Color(white: 0.38)

    static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let monoBold = Font.system(size: 13, weight: .semibold, design: .monospaced)
}

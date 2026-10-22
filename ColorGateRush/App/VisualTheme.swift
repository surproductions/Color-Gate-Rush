import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    convenience init(_ rgb: RGB, alpha: CGFloat = 1) {
        self.init(red: CGFloat(rgb.r), green: CGFloat(rgb.g), blue: CGFloat(rgb.b), alpha: alpha)
    }
}

extension GateColor {
    var uiColor: UIColor { UIColor(rgb) }
    var color: Color { Color(uiColor) }
}

/// Background/track palette for a cosmetic theme. Gate colors never change between themes
/// so the color rules stay consistent.
struct VisualTheme {
    let id: String
    let skyTop: UIColor
    let skyBottom: UIColor
    let track: UIColor
    let trackFar: UIColor
    let edge: UIColor
    let lane: UIColor
    let glow: UIColor
    let star: UIColor

    var skyTopColor: Color { Color(skyTop) }
    var skyBottomColor: Color { Color(skyBottom) }
    var glowColor: Color { Color(glow) }
    var edgeColor: Color { Color(edge) }

    static func theme(for id: String) -> VisualTheme {
        switch id {
        case "theme.synthwave":
            return VisualTheme(id: id, skyTop: UIColor(hex: 0x0E0024), skyBottom: UIColor(hex: 0x4A0B5C),
                               track: UIColor(hex: 0x1A0630), trackFar: UIColor(hex: 0x3A0C4E),
                               edge: UIColor(hex: 0xFF4FD8), lane: UIColor(hex: 0xFF8BEA, alpha: 0.35),
                               glow: UIColor(hex: 0xFF2E97), star: UIColor(hex: 0xFFD1F3))
        case "theme.ocean":
            return VisualTheme(id: id, skyTop: UIColor(hex: 0x00121F), skyBottom: UIColor(hex: 0x00404D),
                               track: UIColor(hex: 0x001A24), trackFar: UIColor(hex: 0x00394A),
                               edge: UIColor(hex: 0x36E2D4), lane: UIColor(hex: 0x7FF5EA, alpha: 0.3),
                               glow: UIColor(hex: 0x00B3C7), star: UIColor(hex: 0xBFFBFF))
        case "theme.ember":
            return VisualTheme(id: id, skyTop: UIColor(hex: 0x140303), skyBottom: UIColor(hex: 0x4A1607),
                               track: UIColor(hex: 0x1E0904), trackFar: UIColor(hex: 0x431507),
                               edge: UIColor(hex: 0xFF8A3D), lane: UIColor(hex: 0xFFB27A, alpha: 0.3),
                               glow: UIColor(hex: 0xFF4E1A), star: UIColor(hex: 0xFFE0C2))
        default:
            return VisualTheme(id: CosmeticCatalog.defaultTheme, skyTop: UIColor(hex: 0x07071F), skyBottom: UIColor(hex: 0x231358),
                               track: UIColor(hex: 0x100E33), trackFar: UIColor(hex: 0x2A1D6E),
                               edge: UIColor(hex: 0x8C7BFF), lane: UIColor(hex: 0xB4A9FF, alpha: 0.3),
                               glow: UIColor(hex: 0x6E4BFF), star: UIColor(hex: 0xDCD8FF))
        }
    }
}

/// Shared vector shapes for the gate symbols, used by SpriteKit textures and SwiftUI alike.
enum SymbolPath {
    static func path(_ symbol: GateSymbol, in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let midX = rect.midX, midY = rect.midY
        switch symbol {
        case .triangle:
            // Optically centred equilateral-ish triangle.
            path.move(to: CGPoint(x: midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.06))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.06))
            path.closeSubpath()
        case .circle:
            path.addEllipse(in: rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06))
        case .square:
            path.addRoundedRect(in: rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.12),
                                cornerWidth: rect.width * 0.08, cornerHeight: rect.height * 0.08)
        case .diamond:
            path.move(to: CGPoint(x: midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: midY))
            path.addLine(to: CGPoint(x: midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: midY))
            path.closeSubpath()
        case .star:
            let outer = min(rect.width, rect.height) / 2
            let inner = outer * 0.45
            for i in 0..<10 {
                let radius = i.isMultiple(of: 2) ? outer : inner
                let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
                let point = CGPoint(x: midX + cos(angle) * radius, y: midY + sin(angle) * radius * 1.0 + outer * 0.06)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
        return path
    }
}

/// SwiftUI wrapper so menus can draw the exact same symbols.
struct GateSymbolShape: Shape {
    let symbol: GateSymbol

    func path(in rect: CGRect) -> Path {
        Path(SymbolPath.path(symbol, in: rect))
    }
}

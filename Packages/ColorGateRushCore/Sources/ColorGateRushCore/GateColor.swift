import Foundation

/// A plain RGB triple (0...1) so the rules layer can describe colors without UIKit.
struct RGB: Equatable, Hashable {
    let r: Double
    let g: Double
    let b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}

/// Every gate color is paired with a unique shape so the game never relies on hue alone.
enum GateSymbol: String, CaseIterable {
    case triangle, circle, square, diamond, star
}

/// The colors an orb and a gate can have. Order matters: lower tiers use the first N colors.
enum GateColor: Int, CaseIterable, Codable, Hashable {
    case crimson, amber, lime, azure, violet

    var displayName: String {
        switch self {
        case .crimson: return "Crimson"
        case .amber: return "Amber"
        case .lime: return "Lime"
        case .azure: return "Azure"
        case .violet: return "Violet"
        }
    }

    var symbol: GateSymbol {
        switch self {
        case .crimson: return .triangle
        case .amber: return .circle
        case .lime: return .square
        case .azure: return .diamond
        case .violet: return .star
        }
    }

    var rgb: RGB {
        switch self {
        case .crimson: return RGB(1.00, 0.24, 0.38)
        case .amber: return RGB(1.00, 0.74, 0.14)
        case .lime: return RGB(0.36, 0.93, 0.42)
        case .azure: return RGB(0.18, 0.64, 1.00)
        case .violet: return RGB(0.74, 0.40, 1.00)
        }
    }

    /// The first `count` colors, clamped to the palette size and to at least two.
    static func palette(count: Int) -> [GateColor] {
        let n = min(max(count, 2), allCases.count)
        return Array(allCases.prefix(n))
    }
}

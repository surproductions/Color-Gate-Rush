import Foundation

/// What occupies a single lane of a track row.
enum LaneContent: Equatable {
    /// Nothing here; always safe.
    case open
    /// A colored gate: safe only when the orb has the same color.
    case gate(GateColor)
    /// A barrier: never safe.
    case hazard
    /// A collectible shard (currency + points).
    case shard
    /// A one-hit shield pickup.
    case shield
    /// A prism that recolors the orb. Prism rows always span every lane.
    case prism(GateColor)

    func isSafe(for color: GateColor) -> Bool {
        switch self {
        case .hazard:
            return false
        case .gate(let gateColor):
            return gateColor == color
        case .open, .shard, .shield, .prism:
            return true
        }
    }

    var isPickup: Bool {
        switch self {
        case .shard, .shield: return true
        default: return false
        }
    }
}

enum RowKind: Equatable {
    case gate, hazard, pickup, prism
}

/// One horizontal slice of the course. The orb resolves a row exactly once,
/// at the moment its travelled distance reaches `position`.
struct TrackRow: Identifiable, Equatable {
    let id: Int
    let position: Double
    let kind: RowKind
    var lanes: [LaneContent]
    var resolved = false
    /// Lane the orb occupied when the row was resolved.
    var resolvedLane: Int?
    /// Optional coaching text (tutorial only).
    var hint: String?

    /// The orb color after passing this row, given the color before it.
    func colorAfter(_ color: GateColor) -> GateColor {
        if kind == .prism, case .prism(let newColor)? = lanes.first {
            return newColor
        }
        return color
    }

    func safeLanes(for color: GateColor) -> Set<Int> {
        Set(lanes.indices.filter { lanes[$0].isSafe(for: color) })
    }
}

enum TrackConstants {
    static let laneCount = 3
    static let startLane = 1
}

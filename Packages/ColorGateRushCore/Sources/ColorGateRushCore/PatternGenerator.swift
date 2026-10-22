import Foundation

/// Anything that can feed rows to a `GameSession`, in increasing position order.
protocol RowSource {
    /// Returns the next row, or nil when the course is finished (tutorial only).
    mutating func nextRow() -> TrackRow?
}

/// Procedural course builder.
///
/// Fairness guarantee: for every lane that is safe in row *i*, at least one safe lane of
/// row *i+1* is reachable within the number of lane switches a player can make in the time
/// between the two rows (see `DifficultyModel.reach`). By induction, a player who has
/// survived so far can always survive the next row, so the generator never builds a trap.
/// Because prism rows span every lane, the orb's color at every row is known in advance.
struct PatternGenerator: RowSource {
    private enum Spec: Equatable {
        case gate(hazardBoost: Double)
        case hazard
        case shardTrail
        case prism
        case breather(allowShield: Bool)
    }

    private struct Pending {
        let spec: Spec
        let gapFactor: Double
    }

    let seed: UInt64
    private var rng: SeededRandom
    /// The orb color the player will have when reaching the next generated row.
    private(set) var plannedColor: GateColor
    private var previousSafe: Set<Int>
    private var lastPosition: Double?
    private let firstRowPosition: Double
    private var nextID: Int
    private var queue: [Pending] = []
    private var rowsSincePrism = 0
    private var rowsSinceShield = 0
    private var shardLane: Int
    private let laneCount = TrackConstants.laneCount

    /// Rows between shield offers; shields are rare by design.
    static let shieldCooldownRows = 30

    init(seed: UInt64,
         startColor: GateColor = .crimson,
         startLane: Int = TrackConstants.startLane,
         firstRowPosition: Double = 24,
         firstID: Int = 0) {
        self.seed = seed
        self.rng = SeededRandom(seed: seed)
        self.plannedColor = startColor
        self.previousSafe = [startLane]
        self.firstRowPosition = firstRowPosition
        self.nextID = firstID
        self.shardLane = startLane
    }

    mutating func nextRow() -> TrackRow? {
        if queue.isEmpty { enqueuePattern() }
        let pending = queue.removeFirst()

        let position: Double
        let reach: Int
        if let last = lastPosition {
            let anchor = DifficultyModel.parameters(at: last)
            let gap = max(DifficultyModel.minimumFairGap, anchor.gapTime * pending.gapFactor)
            // 4% extra distance compensates for the speed increase while crossing the gap,
            // so the real time between rows is never below `gap`.
            position = last + gap * anchor.speed * 1.04
            reach = DifficultyModel.reach(forGapTime: gap)
        } else {
            position = firstRowPosition
            reach = laneCount
        }

        let params = DifficultyModel.parameters(at: position)
        let made = makeLanes(pending.spec, params: params)
        let kind = made.0
        var lanes = made.1
        if kind == .gate || kind == .hazard {
            repair(&lanes, kind: kind, reach: reach)
        }

        let row = TrackRow(id: nextID, position: position, kind: kind, lanes: lanes)
        nextID += 1
        lastPosition = position

        if kind == .prism {
            previousSafe = Set(0..<laneCount)
            rowsSincePrism = 0
        } else {
            previousSafe = row.safeLanes(for: plannedColor)
            rowsSincePrism += 1
        }
        if lanes.contains(.shield) {
            rowsSinceShield = 0
        } else {
            rowsSinceShield += 1
        }
        plannedColor = row.colorAfter(plannedColor)
        return row
    }

    // MARK: - Pattern selection

    private mutating func enqueuePattern() {
        guard let last = lastPosition else {
            queue = [Pending(spec: .breather(allowShield: false), gapFactor: 1),
                     Pending(spec: .gate(hazardBoost: 0), gapFactor: 1.2)]
            return
        }
        let params = DifficultyModel.parameters(at: last)
        var w = params.weights
        if rowsSincePrism < 4 {
            w.prismSwitch = 0
        } else if rowsSincePrism > 12 {
            w.prismSwitch *= 4
        }
        let choice = rng.weightedIndex([w.singleGate, w.gateRun, w.hazardSlalom, w.prismSwitch,
                                        w.shardTrail, w.mixed, w.breather])
        switch choice {
        case 0:
            queue = [Pending(spec: .gate(hazardBoost: 0), gapFactor: 1)]
        case 1:
            let maxRun = params.tier >= .overdrive ? 4 : 3
            let count = rng.int(in: 2...maxRun)
            queue = [Pending(spec: .gate(hazardBoost: 0), gapFactor: 1)]
                + Array(repeating: Pending(spec: .gate(hazardBoost: 0), gapFactor: 0.85), count: count - 1)
        case 2:
            let count = rng.int(in: 2...3)
            queue = Array(repeating: Pending(spec: .hazard, gapFactor: 0.9), count: count)
        case 3:
            // Extra time after a recolor so the new rule can sink in.
            queue = [Pending(spec: .prism, gapFactor: 1), Pending(spec: .gate(hazardBoost: 0), gapFactor: 1.15)]
        case 4:
            let count = rng.int(in: 3...5)
            queue = Array(repeating: Pending(spec: .shardTrail, gapFactor: 0.55), count: count)
        case 5:
            queue = [Pending(spec: .gate(hazardBoost: 0.3), gapFactor: 1),
                     Pending(spec: .hazard, gapFactor: 0.9),
                     Pending(spec: .gate(hazardBoost: 0.3), gapFactor: 0.9)]
        default:
            let allowShield = params.tier >= .rush && rowsSinceShield >= Self.shieldCooldownRows
            queue = [Pending(spec: .breather(allowShield: allowShield), gapFactor: 1.3)]
        }
    }

    // MARK: - Row construction

    private mutating func makeLanes(_ spec: Spec, params: DifficultyParameters) -> (RowKind, [LaneContent]) {
        var lanes = [LaneContent](repeating: .open, count: laneCount)
        switch spec {
        case .gate(let boost):
            var colors = params.colors
            if !colors.contains(plannedColor) { colors.append(plannedColor) }
            let others = colors.filter { $0 != plannedColor }
            let matchCount = rng.int(in: params.matchingLanes)
            let order = rng.shuffled(Array(0..<laneCount))
            for (index, lane) in order.enumerated() {
                if index < matchCount {
                    lanes[lane] = .gate(plannedColor)
                } else if rng.chance(min(0.9, params.gateHazardChance + boost)) {
                    lanes[lane] = .hazard
                } else {
                    lanes[lane] = .gate(rng.pick(others))
                }
            }
            return (.gate, lanes)

        case .hazard:
            let count = rng.chance(params.doubleHazardChance) ? 2 : 1
            let order = rng.shuffled(Array(0..<laneCount))
            for (index, lane) in order.enumerated() {
                if index < count {
                    lanes[lane] = .hazard
                } else if rng.chance(params.shardChance) {
                    lanes[lane] = .shard
                }
            }
            return (.hazard, lanes)

        case .shardTrail:
            shardLane = min(laneCount - 1, max(0, shardLane + rng.int(in: -1...1)))
            lanes[shardLane] = .shard
            return (.pickup, lanes)

        case .prism:
            let choices = params.colors.filter { $0 != plannedColor }
            let newColor = choices.isEmpty ? plannedColor : rng.pick(choices)
            return (.prism, [LaneContent](repeating: .prism(newColor), count: laneCount))

        case .breather(let allowShield):
            let special = rng.int(in: 0...(laneCount - 1))
            for lane in 0..<laneCount {
                if lane == special {
                    lanes[lane] = (allowShield && rng.chance(0.6)) ? .shield : .shard
                } else if rng.chance(0.3) {
                    lanes[lane] = .shard
                }
            }
            return (.pickup, lanes)
        }
    }

    /// Enforces the fairness invariant against the previous row's safe lanes.
    private mutating func repair(_ lanes: inout [LaneContent], kind: RowKind, reach: Int) {
        let color = plannedColor
        for origin in previousSafe.sorted() {
            let lo = max(0, origin - reach)
            let hi = min(laneCount - 1, origin + reach)
            let reachable = (lo...hi).contains { lanes[$0].isSafe(for: color) }
            if !reachable {
                let target = rng.int(in: lo...hi)
                lanes[target] = kind == .gate ? .gate(color) : .open
            }
        }
    }
}

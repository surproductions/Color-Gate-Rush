import Foundation

/// Named difficulty stages. Each unlocks more colors and denser patterns.
enum Tier: Int, CaseIterable, Codable, Comparable {
    case warmUp, rush, overdrive, hyper, prismatic

    static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }

    var name: String {
        switch self {
        case .warmUp: return "Warm-Up"
        case .rush: return "Rush"
        case .overdrive: return "Overdrive"
        case .hyper: return "Hyper"
        case .prismatic: return "Prismatic"
        }
    }

    /// Distance (track units, shown to players as metres) at which the tier begins.
    var startDistance: Double {
        switch self {
        case .warmUp: return 0
        case .rush: return 350
        case .overdrive: return 1000
        case .hyper: return 2000
        case .prismatic: return 3500
        }
    }

    var colorCount: Int {
        switch self {
        case .warmUp: return 2
        case .rush: return 3
        case .overdrive: return 4
        case .hyper, .prismatic: return 5
        }
    }

    static func forDistance(_ distance: Double) -> Tier {
        var result = Tier.warmUp
        for tier in allCases where distance >= tier.startDistance {
            result = tier
        }
        return result
    }
}

/// Relative likelihood of each pattern family being chosen next.
struct PatternWeights: Equatable {
    var singleGate: Double
    var gateRun: Double
    var hazardSlalom: Double
    var prismSwitch: Double
    var shardTrail: Double
    var mixed: Double
    var breather: Double
}

struct DifficultyParameters: Equatable {
    let tier: Tier
    /// Forward speed in units per second.
    let speed: Double
    /// Intended time between consecutive rows, in seconds.
    let gapTime: Double
    /// How many lanes of a gate row match the orb (inclusive range).
    let matchingLanes: ClosedRange<Int>
    /// Chance a non-matching gate lane is replaced by a hazard.
    let gateHazardChance: Double
    /// Chance a hazard row blocks two lanes instead of one.
    let doubleHazardChance: Double
    /// Chance an open lane in a hazard row carries a shard.
    let shardChance: Double
    let weights: PatternWeights

    var colors: [GateColor] { GateColor.palette(count: tier.colorCount) }
}

/// Central difficulty curve. Speed and spacing ease smoothly toward hard caps so the
/// game ramps continuously but never becomes physically unplayable.
enum DifficultyModel {
    static let baseSpeed = 9.0
    static let maxSpeed = 17.5
    static let speedScale = 2400.0

    static let maxGapTime = 1.15
    static let minGapTime = 0.56
    static let gapScale = 1500.0

    /// Assumed human limits used by the fairness guarantee.
    static let reactionTime = 0.30
    static let laneSwitchTime = 0.14

    /// The smallest row spacing (seconds) the generator may ever produce:
    /// enough to react and move one lane, with a 5% margin.
    static var minimumFairGap: Double { (reactionTime + laneSwitchTime) * 1.05 }

    static func speed(at distance: Double) -> Double {
        let d = max(0, distance)
        return baseSpeed + (maxSpeed - baseSpeed) * (1 - exp(-d / speedScale))
    }

    static func gapTime(at distance: Double) -> Double {
        let d = max(0, distance)
        return minGapTime + (maxGapTime - minGapTime) * exp(-d / gapScale)
    }

    /// Number of lanes a player can reliably cross in the given time between rows.
    static func reach(forGapTime gap: Double) -> Int {
        if gap >= reactionTime + 2 * laneSwitchTime { return 2 }
        return 1
    }

    static func parameters(at distance: Double) -> DifficultyParameters {
        let tier = Tier.forDistance(distance)
        switch tier {
        case .warmUp:
            return DifficultyParameters(
                tier: tier, speed: speed(at: distance), gapTime: gapTime(at: distance),
                matchingLanes: 1...2, gateHazardChance: 0.0, doubleHazardChance: 0.0, shardChance: 0.35,
                weights: PatternWeights(singleGate: 4, gateRun: 1, hazardSlalom: 1.5, prismSwitch: 1.6,
                                        shardTrail: 1.2, mixed: 0, breather: 0.6))
        case .rush:
            return DifficultyParameters(
                tier: tier, speed: speed(at: distance), gapTime: gapTime(at: distance),
                matchingLanes: 1...2, gateHazardChance: 0.15, doubleHazardChance: 0.25, shardChance: 0.3,
                weights: PatternWeights(singleGate: 3, gateRun: 2, hazardSlalom: 1.5, prismSwitch: 2,
                                        shardTrail: 1, mixed: 1, breather: 0.6))
        case .overdrive:
            return DifficultyParameters(
                tier: tier, speed: speed(at: distance), gapTime: gapTime(at: distance),
                matchingLanes: 1...2, gateHazardChance: 0.3, doubleHazardChance: 0.45, shardChance: 0.3,
                weights: PatternWeights(singleGate: 2, gateRun: 2.5, hazardSlalom: 1.5, prismSwitch: 2.4,
                                        shardTrail: 0.8, mixed: 2, breather: 0.5))
        case .hyper:
            return DifficultyParameters(
                tier: tier, speed: speed(at: distance), gapTime: gapTime(at: distance),
                matchingLanes: 1...1, gateHazardChance: 0.35, doubleHazardChance: 0.6, shardChance: 0.25,
                weights: PatternWeights(singleGate: 1.5, gateRun: 3, hazardSlalom: 1.5, prismSwitch: 2.8,
                                        shardTrail: 0.6, mixed: 2.5, breather: 0.45))
        case .prismatic:
            return DifficultyParameters(
                tier: tier, speed: speed(at: distance), gapTime: gapTime(at: distance),
                matchingLanes: 1...1, gateHazardChance: 0.45, doubleHazardChance: 0.7, shardChance: 0.25,
                weights: PatternWeights(singleGate: 1, gateRun: 3, hazardSlalom: 1.5, prismSwitch: 3.2,
                                        shardTrail: 0.5, mixed: 3, breather: 0.4))
        }
    }
}

import Foundation

/// The single source of truth for points and rewards.
///
/// Formula:
/// - Matching gate: `10 × multiplier`, where `multiplier = min(5, 1 + combo / 8)` and
///   `combo` counts consecutive matched gates including this one (x2 at 8, x3 at 16, … x5 at 32).
/// - Shard: +5 points and +1 shard. Prism: +2 points. Extra shield while holding one: +25 points.
/// - Every 25 gates passed in a run: +100 milestone bonus.
/// - Any hit (wrong color or barrier) resets the combo.
/// - Shards banked after a run: shards collected + 1 per 250 points.
enum ScoreRules {
    static let gateBase = 10
    static let comboStep = 8
    static let maxMultiplier = 5
    static let shardPoints = 5
    static let prismPoints = 2
    static let spareShieldPoints = 25
    static let milestoneInterval = 25
    static let milestoneBonus = 100
    static let pointsPerBonusShard = 250

    static func multiplier(forCombo combo: Int) -> Int {
        min(maxMultiplier, 1 + max(0, combo) / comboStep)
    }

    static func gatePoints(combo: Int) -> Int {
        gateBase * multiplier(forCombo: combo)
    }

    static func isMilestone(gatesPassed: Int) -> Bool {
        gatesPassed > 0 && gatesPassed % milestoneInterval == 0
    }

    static func shardsEarned(collected: Int, score: Int) -> Int {
        max(0, collected) + max(0, score) / pointsPerBonusShard
    }
}

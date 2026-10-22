import XCTest
@testable import ColorGateRushCore

final class ProgressionTests: XCTestCase {

    private func run(score: Int = 0, gates: Int = 0, combo: Int = 0, shards: Int = 0, shields: Int = 0,
                     tier: Tier = .warmUp, tutorial: Bool = false, distance: Double = 100) -> RunSummary {
        RunSummary(id: UUID(), isTutorial: tutorial, completedTutorial: tutorial, score: score, distance: distance,
                   gatesPassed: gates, maxCombo: combo, shardsCollected: shards, shieldsUsed: shields,
                   prismsPassed: 0, tierReached: tier, duration: 30, seed: 1)
    }

    func testScoreRules() {
        XCTAssertEqual(ScoreRules.multiplier(forCombo: 0), 1)
        XCTAssertEqual(ScoreRules.multiplier(forCombo: 7), 1)
        XCTAssertEqual(ScoreRules.multiplier(forCombo: 8), 2)
        XCTAssertEqual(ScoreRules.multiplier(forCombo: 16), 3)
        XCTAssertEqual(ScoreRules.multiplier(forCombo: 1000), ScoreRules.maxMultiplier)
        XCTAssertEqual(ScoreRules.multiplier(forCombo: -5), 1)
        XCTAssertEqual(ScoreRules.gatePoints(combo: 1), 10)
        XCTAssertEqual(ScoreRules.gatePoints(combo: 40), 50)
        XCTAssertTrue(ScoreRules.isMilestone(gatesPassed: 25))
        XCTAssertFalse(ScoreRules.isMilestone(gatesPassed: 0))
        XCTAssertFalse(ScoreRules.isMilestone(gatesPassed: 26))
        XCTAssertEqual(ScoreRules.shardsEarned(collected: 4, score: 600), 6)
        XCTAssertEqual(ScoreRules.shardsEarned(collected: -3, score: -10), 0)
    }

    func testBestScoreOnlyIncreases() {
        var profile = PlayerProfile()
        let first = ProgressionEngine.apply(run(score: 500), to: &profile)
        XCTAssertEqual(first?.isNewBest, true)
        XCTAssertEqual(profile.bestScore, 500)
        let second = ProgressionEngine.apply(run(score: 200), to: &profile)
        XCTAssertEqual(second?.isNewBest, false)
        XCTAssertEqual(second?.previousBest, 500)
        XCTAssertEqual(profile.bestScore, 500)
        XCTAssertEqual(profile.totalRuns, 2)
        XCTAssertEqual(profile.recentRuns.first?.score, 200)
    }

    func testRunIsAppliedOnlyOnce() {
        var profile = PlayerProfile()
        let summary = run(score: 1200, gates: 30, shards: 10)
        let rewards = ProgressionEngine.apply(summary, to: &profile)
        XCTAssertNotNil(rewards)
        let shardsAfter = profile.shards
        XCTAssertNil(ProgressionEngine.apply(summary, to: &profile))
        XCTAssertEqual(profile.shards, shardsAfter)
        XCTAssertEqual(profile.totalRuns, 1)
    }

    func testAchievementsUnlockOnceAndPayOut() {
        var profile = PlayerProfile()
        let rewards = ProgressionEngine.apply(run(score: 1200, gates: 30, combo: 22, tier: .rush), to: &profile)!
        XCTAssertTrue(rewards.newAchievementIDs.contains("ach.gates25"))
        XCTAssertTrue(rewards.newAchievementIDs.contains("ach.score1000"))
        XCTAssertTrue(rewards.newAchievementIDs.contains("ach.combo20"))
        XCTAssertTrue(rewards.newAchievementIDs.contains("ach.rush"))
        XCTAssertFalse(rewards.newAchievementIDs.contains("ach.overdrive"))
        let expected = rewards.newAchievementIDs.compactMap { AchievementCatalog.achievement($0)?.reward }.reduce(0, +)
        XCTAssertEqual(rewards.shardsFromAchievements, expected)
        XCTAssertEqual(profile.shards, rewards.totalShards)

        let again = ProgressionEngine.apply(run(score: 1300, gates: 31, combo: 25, tier: .rush), to: &profile)!
        XCTAssertTrue(again.newAchievementIDs.isEmpty)
        XCTAssertEqual(again.shardsFromAchievements, 0)
    }

    func testTutorialRunMarksCompletionWithoutStats() {
        var profile = PlayerProfile()
        let rewards = ProgressionEngine.apply(run(score: 300, gates: 4, tutorial: true), to: &profile)!
        XCTAssertTrue(profile.tutorialCompleted)
        XCTAssertEqual(profile.totalRuns, 0)
        XCTAssertEqual(profile.bestScore, 0)
        XCTAssertEqual(rewards.newAchievementIDs, ["ach.tutorial"])
        XCTAssertEqual(profile.shards, 20)
    }

    func testLifetimeAchievements() {
        var profile = PlayerProfile()
        profile.totalRuns = 24
        profile.totalGates = 990
        let rewards = ProgressionEngine.apply(run(gates: 10), to: &profile)!
        XCTAssertTrue(rewards.newAchievementIDs.contains("ach.runs25"))
        XCTAssertTrue(rewards.newAchievementIDs.contains("ach.gates1000"))
    }

    func testPurchaseRules() {
        var profile = PlayerProfile()
        XCTAssertEqual(ProgressionEngine.purchase("skin.pulse", profile: &profile), .insufficientFunds(missing: 60))
        XCTAssertFalse(profile.unlockedItems.contains("skin.pulse"))
        profile.shards = 100
        XCTAssertEqual(ProgressionEngine.purchase("skin.pulse", profile: &profile), .purchased)
        XCTAssertEqual(profile.shards, 40)
        XCTAssertEqual(ProgressionEngine.purchase("skin.pulse", profile: &profile), .alreadyOwned)
        XCTAssertEqual(profile.shards, 40, "no double spend")
        XCTAssertEqual(ProgressionEngine.purchase("skin.nope", profile: &profile), .unknownItem)
        XCTAssertEqual(ProgressionEngine.purchase(CosmeticCatalog.defaultSkin, profile: &profile), .alreadyOwned)
    }

    func testEquipRequiresOwnership() {
        var profile = PlayerProfile()
        XCTAssertFalse(ProgressionEngine.equip("theme.ember", profile: &profile))
        XCTAssertEqual(profile.selectedTheme, CosmeticCatalog.defaultTheme)
        profile.shards = 1000
        _ = ProgressionEngine.purchase("theme.ember", profile: &profile)
        XCTAssertTrue(ProgressionEngine.equip("theme.ember", profile: &profile))
        XCTAssertEqual(profile.selectedTheme, "theme.ember")
        XCTAssertEqual(profile.selectedSkin, CosmeticCatalog.defaultSkin, "equipping a theme leaves the skin alone")
    }

    func testContentTargets() {
        XCTAssertGreaterThanOrEqual(CosmeticCatalog.items(in: .skin).count, 8)
        XCTAssertGreaterThanOrEqual(CosmeticCatalog.all.filter { $0.cost > 0 }.count, 8)
        XCTAssertGreaterThanOrEqual(AchievementCatalog.all.count, 10)
        XCTAssertEqual(Set(CosmeticCatalog.all.map(\.id)).count, CosmeticCatalog.all.count)
        XCTAssertEqual(Set(AchievementCatalog.all.map(\.id)).count, AchievementCatalog.all.count)
        XCTAssertEqual(Set(GateColor.allCases.map(\.symbol)).count, GateColor.allCases.count, "unique shapes per color")
    }
}

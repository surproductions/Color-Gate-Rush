import Foundation

// MARK: - Cosmetics

enum CosmeticCategory: String, Codable, CaseIterable {
    case skin, trail, theme

    var displayName: String {
        switch self {
        case .skin: return "Orbs"
        case .trail: return "Trails"
        case .theme: return "Themes"
        }
    }
}

struct CosmeticItem: Identifiable, Equatable {
    let id: String
    let category: CosmeticCategory
    let name: String
    let detail: String
    let cost: Int
}

enum CosmeticCatalog {
    static let defaultSkin = "skin.core"
    static let defaultTrail = "trail.spark"
    static let defaultTheme = "theme.midnight"
    static let defaultItemIDs: Set<String> = [defaultSkin, defaultTrail, defaultTheme]

    static let all: [CosmeticItem] = [
        CosmeticItem(id: "skin.core", category: .skin, name: "Core", detail: "The classic glowing orb.", cost: 0),
        CosmeticItem(id: "skin.pulse", category: .skin, name: "Pulse", detail: "A core wrapped in a bright ring.", cost: 60),
        CosmeticItem(id: "skin.hex", category: .skin, name: "Hex Core", detail: "Sharp hexagonal plating.", cost: 120),
        CosmeticItem(id: "skin.comet", category: .skin, name: "Comet", detail: "Streamlined for speed.", cost: 180),
        CosmeticItem(id: "skin.star", category: .skin, name: "Starburst", detail: "A five-pointed star that spins.", cost: 250),
        CosmeticItem(id: "skin.halo", category: .skin, name: "Twin Halo", detail: "Double orbit rings.", cost: 320),
        CosmeticItem(id: "skin.nova", category: .skin, name: "Nova", detail: "Radiates spikes of light.", cost: 400),
        CosmeticItem(id: "skin.gem", category: .skin, name: "Void Gem", detail: "A faceted crystal core.", cost: 500),

        CosmeticItem(id: "trail.spark", category: .trail, name: "Sparks", detail: "Glowing embers.", cost: 0),
        CosmeticItem(id: "trail.ribbon", category: .trail, name: "Ribbon", detail: "A smooth continuous streak.", cost: 80),
        CosmeticItem(id: "trail.bubble", category: .trail, name: "Bubbles", detail: "Soft drifting bubbles.", cost: 150),
        CosmeticItem(id: "trail.pixel", category: .trail, name: "Pixels", detail: "Retro square bits.", cost: 220),
        CosmeticItem(id: "trail.rainbow", category: .trail, name: "Spectrum", detail: "Cycles through every gate color.", cost: 450),

        CosmeticItem(id: "theme.midnight", category: .theme, name: "Midnight", detail: "Deep indigo night.", cost: 0),
        CosmeticItem(id: "theme.synthwave", category: .theme, name: "Synthwave", detail: "Magenta horizon glow.", cost: 150),
        CosmeticItem(id: "theme.ocean", category: .theme, name: "Deep Ocean", detail: "Cool abyssal teal.", cost: 200),
        CosmeticItem(id: "theme.ember", category: .theme, name: "Ember", detail: "Smoldering volcanic dusk.", cost: 300)
    ]

    static let allIDs: Set<String> = Set(all.map(\.id))

    static func item(_ id: String) -> CosmeticItem? {
        all.first { $0.id == id }
    }

    static func items(in category: CosmeticCategory) -> [CosmeticItem] {
        all.filter { $0.category == category }
    }
}

// MARK: - Achievements

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    /// Shards granted once when unlocked.
    let reward: Int
    /// SF Symbol name used by the UI.
    let icon: String
    let isMet: (RunSummary, PlayerProfile) -> Bool
}

enum AchievementCatalog {
    /// Conditions are evaluated after the run's totals have been added to the profile.
    static let all: [Achievement] = [
        Achievement(id: "ach.tutorial", title: "First Steps", detail: "Complete the tutorial.", reward: 20,
                    icon: "graduationcap.fill") { run, profile in run.completedTutorial || profile.tutorialCompleted },
        Achievement(id: "ach.gates25", title: "Gatecrasher", detail: "Pass 25 gates in one run.", reward: 30,
                    icon: "door.left.hand.open") { run, _ in !run.isTutorial && run.gatesPassed >= 25 },
        Achievement(id: "ach.score1000", title: "Four Digits", detail: "Score 1,000 points in one run.", reward: 40,
                    icon: "number") { run, _ in !run.isTutorial && run.score >= 1000 },
        Achievement(id: "ach.score5000", title: "High Roller", detail: "Score 5,000 points in one run.", reward: 100,
                    icon: "crown.fill") { run, _ in !run.isTutorial && run.score >= 5000 },
        Achievement(id: "ach.combo20", title: "In the Zone", detail: "Reach a 20-gate combo.", reward: 40,
                    icon: "flame.fill") { run, _ in !run.isTutorial && run.maxCombo >= 20 },
        Achievement(id: "ach.combo50", title: "Unbreakable", detail: "Reach a 50-gate combo.", reward: 100,
                    icon: "bolt.heart.fill") { run, _ in !run.isTutorial && run.maxCombo >= 50 },
        Achievement(id: "ach.rush", title: "Rush Hour", detail: "Reach the Rush tier.", reward: 25,
                    icon: "hare.fill") { run, _ in !run.isTutorial && run.tierReached >= .rush },
        Achievement(id: "ach.overdrive", title: "Overdrive", detail: "Reach the Overdrive tier.", reward: 50,
                    icon: "speedometer") { run, _ in !run.isTutorial && run.tierReached >= .overdrive },
        Achievement(id: "ach.hyper", title: "Hyperspace", detail: "Reach the Hyper tier.", reward: 100,
                    icon: "sparkles") { run, _ in !run.isTutorial && run.tierReached >= .hyper },
        Achievement(id: "ach.prismatic", title: "Prismatic", detail: "Reach the Prismatic tier.", reward: 200,
                    icon: "rainbow") { run, _ in !run.isTutorial && run.tierReached >= .prismatic },
        Achievement(id: "ach.shards30", title: "Pocketful", detail: "Collect 30 shards in one run.", reward: 30,
                    icon: "diamond.fill") { run, _ in !run.isTutorial && run.shardsCollected >= 30 },
        Achievement(id: "ach.shards500", title: "Shard Hoarder", detail: "Collect 500 shards in total.", reward: 80,
                    icon: "bag.fill") { _, profile in profile.totalShardsCollected >= 500 },
        Achievement(id: "ach.shield", title: "Close Call", detail: "Let a shield absorb a hit.", reward: 25,
                    icon: "shield.lefthalf.filled") { run, _ in !run.isTutorial && run.shieldsUsed > 0 },
        Achievement(id: "ach.runs25", title: "Dedicated", detail: "Play 25 runs.", reward: 50,
                    icon: "repeat") { _, profile in profile.totalRuns >= 25 },
        Achievement(id: "ach.gates1000", title: "Gate Legend", detail: "Pass 1,000 gates in total.", reward: 120,
                    icon: "trophy.fill") { _, profile in profile.totalGates >= 1000 }
    ]

    static let allIDs: Set<String> = Set(all.map(\.id))

    static func achievement(_ id: String) -> Achievement? {
        all.first { $0.id == id }
    }
}

// MARK: - Rewards and purchases

struct RunRewards: Equatable {
    let shardsFromRun: Int
    let shardsFromAchievements: Int
    let isNewBest: Bool
    let previousBest: Int
    let newAchievementIDs: [String]

    var totalShards: Int { shardsFromRun + shardsFromAchievements }
}

enum PurchaseResult: Equatable {
    case purchased
    case alreadyOwned
    case insufficientFunds(missing: Int)
    case unknownItem
}

/// Applies run results and purchases to a profile. All mutations of progression go through here.
enum ProgressionEngine {
    /// Applies a finished run exactly once. Returns nil if this run was already applied,
    /// which protects against duplicate callbacks granting rewards twice.
    static func apply(_ run: RunSummary, to profile: inout PlayerProfile, date: Date = Date()) -> RunRewards? {
        guard profile.lastAppliedRunID != run.id else { return nil }
        profile.lastAppliedRunID = run.id

        let previousBest = profile.bestScore
        var shardsFromRun = 0
        var isNewBest = false

        if run.isTutorial {
            if run.completedTutorial { profile.tutorialCompleted = true }
        } else {
            profile.totalRuns += 1
            profile.totalGates += max(0, run.gatesPassed)
            profile.totalShardsCollected += max(0, run.shardsCollected)
            isNewBest = run.score > profile.bestScore
            profile.bestScore = max(profile.bestScore, run.score)
            profile.bestDistance = max(profile.bestDistance, run.distance)
            profile.bestCombo = max(profile.bestCombo, run.maxCombo)
            profile.highestTier = max(profile.highestTier, run.tierReached)
            shardsFromRun = ScoreRules.shardsEarned(collected: run.shardsCollected, score: run.score)
            profile.shards += shardsFromRun
            let record = RunRecord(date: date, score: run.score, distance: run.distance, tier: run.tierReached)
            profile.recentRuns.insert(record, at: 0)
            if profile.recentRuns.count > PlayerProfile.maxRecentRuns {
                profile.recentRuns.removeLast(profile.recentRuns.count - PlayerProfile.maxRecentRuns)
            }
        }

        var newAchievements: [String] = []
        var achievementShards = 0
        for achievement in AchievementCatalog.all where !profile.achievements.contains(achievement.id) {
            if achievement.isMet(run, profile) {
                profile.achievements.insert(achievement.id)
                newAchievements.append(achievement.id)
                achievementShards += achievement.reward
            }
        }
        profile.shards += achievementShards

        return RunRewards(shardsFromRun: shardsFromRun,
                          shardsFromAchievements: achievementShards,
                          isNewBest: isNewBest,
                          previousBest: previousBest,
                          newAchievementIDs: newAchievements)
    }

    static func purchase(_ itemID: String, profile: inout PlayerProfile) -> PurchaseResult {
        guard let item = CosmeticCatalog.item(itemID) else { return .unknownItem }
        guard !profile.unlockedItems.contains(itemID) else { return .alreadyOwned }
        guard profile.shards >= item.cost else {
            return .insufficientFunds(missing: item.cost - profile.shards)
        }
        profile.shards -= item.cost
        profile.unlockedItems.insert(itemID)
        return .purchased
    }

    /// Equips an owned item. Returns false if it is unknown or locked.
    @discardableResult
    static func equip(_ itemID: String, profile: inout PlayerProfile) -> Bool {
        guard let item = CosmeticCatalog.item(itemID), profile.unlockedItems.contains(itemID) else { return false }
        switch item.category {
        case .skin: profile.selectedSkin = itemID
        case .trail: profile.selectedTrail = itemID
        case .theme: profile.selectedTheme = itemID
        }
        return true
    }
}

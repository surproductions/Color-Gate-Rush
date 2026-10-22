import Foundation

enum ControlScheme: String, Codable, CaseIterable {
    /// Tap the left/right half of the screen.
    case tap
    /// Swipe left/right anywhere.
    case swipe

    var displayName: String {
        switch self {
        case .tap: return "Tap Sides"
        case .swipe: return "Swipe"
        }
    }
}

struct GameSettings: Codable, Equatable {
    var musicEnabled = true
    var musicVolume = 0.6
    var soundEnabled = true
    var soundVolume = 0.85
    var hapticsEnabled = true
    var reducedMotion = false
    var colorAssist = false
    var controlScheme: ControlScheme = .tap

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ type: T.Type, _ key: CodingKeys) -> T? {
            (try? c.decodeIfPresent(type, forKey: key)) ?? nil
        }
        let defaults = GameSettings()
        musicEnabled = value(Bool.self, .musicEnabled) ?? defaults.musicEnabled
        musicVolume = value(Double.self, .musicVolume) ?? defaults.musicVolume
        soundEnabled = value(Bool.self, .soundEnabled) ?? defaults.soundEnabled
        soundVolume = value(Double.self, .soundVolume) ?? defaults.soundVolume
        hapticsEnabled = value(Bool.self, .hapticsEnabled) ?? defaults.hapticsEnabled
        reducedMotion = value(Bool.self, .reducedMotion) ?? defaults.reducedMotion
        colorAssist = value(Bool.self, .colorAssist) ?? defaults.colorAssist
        controlScheme = value(ControlScheme.self, .controlScheme) ?? defaults.controlScheme
        sanitize()
    }

    mutating func sanitize() {
        musicVolume = Self.clampVolume(musicVolume)
        soundVolume = Self.clampVolume(soundVolume)
    }

    private static func clampVolume(_ value: Double) -> Double {
        guard value.isFinite else { return 0.7 }
        return min(1, max(0, value))
    }
}

struct RunRecord: Codable, Equatable {
    let date: Date
    let score: Int
    let distance: Double
    let tier: Tier
}

/// Everything persisted for the local player. Decoding is tolerant: missing or invalid
/// fields fall back to defaults and `sanitize()` repairs inconsistent values.
struct PlayerProfile: Codable, Equatable {
    static let currentVersion = 1
    static let maxRecentRuns = 10

    var version = PlayerProfile.currentVersion
    var bestScore = 0
    var bestDistance: Double = 0
    var bestCombo = 0
    var highestTier: Tier = .warmUp
    var totalRuns = 0
    var totalGates = 0
    var totalShardsCollected = 0
    var shards = 0
    var unlockedItems: Set<String> = CosmeticCatalog.defaultItemIDs
    var selectedSkin = CosmeticCatalog.defaultSkin
    var selectedTrail = CosmeticCatalog.defaultTrail
    var selectedTheme = CosmeticCatalog.defaultTheme
    var achievements: Set<String> = []
    var tutorialCompleted = false
    var recentRuns: [RunRecord] = []
    var lastAppliedRunID: UUID?
    var settings = GameSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ type: T.Type, _ key: CodingKeys) -> T? {
            (try? c.decodeIfPresent(type, forKey: key)) ?? nil
        }
        let d = PlayerProfile()
        version = value(Int.self, .version) ?? d.version
        bestScore = value(Int.self, .bestScore) ?? d.bestScore
        bestDistance = value(Double.self, .bestDistance) ?? d.bestDistance
        bestCombo = value(Int.self, .bestCombo) ?? d.bestCombo
        highestTier = value(Tier.self, .highestTier) ?? d.highestTier
        totalRuns = value(Int.self, .totalRuns) ?? d.totalRuns
        totalGates = value(Int.self, .totalGates) ?? d.totalGates
        totalShardsCollected = value(Int.self, .totalShardsCollected) ?? d.totalShardsCollected
        shards = value(Int.self, .shards) ?? d.shards
        unlockedItems = value(Set<String>.self, .unlockedItems) ?? d.unlockedItems
        selectedSkin = value(String.self, .selectedSkin) ?? d.selectedSkin
        selectedTrail = value(String.self, .selectedTrail) ?? d.selectedTrail
        selectedTheme = value(String.self, .selectedTheme) ?? d.selectedTheme
        achievements = value(Set<String>.self, .achievements) ?? d.achievements
        tutorialCompleted = value(Bool.self, .tutorialCompleted) ?? d.tutorialCompleted
        recentRuns = value([RunRecord].self, .recentRuns) ?? d.recentRuns
        lastAppliedRunID = value(UUID.self, .lastAppliedRunID)
        settings = value(GameSettings.self, .settings) ?? d.settings
        sanitize()
    }

    /// Repairs out-of-range or inconsistent values from old or tampered save data.
    mutating func sanitize() {
        version = PlayerProfile.currentVersion
        bestScore = max(0, bestScore)
        bestDistance = bestDistance.isFinite ? max(0, bestDistance) : 0
        bestCombo = max(0, bestCombo)
        totalRuns = max(0, totalRuns)
        totalGates = max(0, totalGates)
        totalShardsCollected = max(0, totalShardsCollected)
        shards = max(0, shards)
        let known = CosmeticCatalog.allIDs
        unlockedItems = unlockedItems.intersection(known).union(CosmeticCatalog.defaultItemIDs)
        achievements = achievements.intersection(AchievementCatalog.allIDs)
        if !unlockedItems.contains(selectedSkin) || CosmeticCatalog.item(selectedSkin)?.category != .skin {
            selectedSkin = CosmeticCatalog.defaultSkin
        }
        if !unlockedItems.contains(selectedTrail) || CosmeticCatalog.item(selectedTrail)?.category != .trail {
            selectedTrail = CosmeticCatalog.defaultTrail
        }
        if !unlockedItems.contains(selectedTheme) || CosmeticCatalog.item(selectedTheme)?.category != .theme {
            selectedTheme = CosmeticCatalog.defaultTheme
        }
        if recentRuns.count > PlayerProfile.maxRecentRuns {
            recentRuns = Array(recentRuns.prefix(PlayerProfile.maxRecentRuns))
        }
        settings.sanitize()
    }

    func selected(_ category: CosmeticCategory) -> String {
        switch category {
        case .skin: return selectedSkin
        case .trail: return selectedTrail
        case .theme: return selectedTheme
        }
    }
}

import XCTest
@testable import ColorGateRushCore

final class PersistenceTests: XCTestCase {

    func testFreshStoreReturnsDefaults() {
        let store = ProfileStore(store: InMemoryStore())
        let profile = store.load()
        XCTAssertEqual(profile, PlayerProfile())
        XCTAssertFalse(profile.tutorialCompleted)
        XCTAssertEqual(profile.unlockedItems, CosmeticCatalog.defaultItemIDs)
    }

    func testRoundTrip() {
        let store = ProfileStore(store: InMemoryStore())
        var profile = PlayerProfile()
        profile.bestScore = 4321
        profile.shards = 77
        profile.tutorialCompleted = true
        profile.unlockedItems.insert("skin.hex")
        profile.selectedSkin = "skin.hex"
        profile.achievements = ["ach.rush"]
        profile.settings.musicEnabled = false
        profile.settings.soundVolume = 0.3
        profile.settings.colorAssist = true
        profile.settings.controlScheme = .swipe
        profile.lastAppliedRunID = UUID()
        XCTAssertTrue(store.save(profile))
        XCTAssertEqual(store.load(), profile)
    }

    func testBestScorePersistsAcrossRelaunch() {
        let backing = InMemoryStore()
        var profile = ProfileStore(store: backing).load()
        let summary = RunSummary(id: UUID(), isTutorial: false, completedTutorial: false, score: 900, distance: 400,
                                 gatesPassed: 20, maxCombo: 12, shardsCollected: 3, shieldsUsed: 0, prismsPassed: 2,
                                 tierReached: .rush, duration: 40, seed: 1)
        _ = ProgressionEngine.apply(summary, to: &profile)
        ProfileStore(store: backing).save(profile)
        let relaunched = ProfileStore(store: backing).load()
        XCTAssertEqual(relaunched.bestScore, 900)
        XCTAssertEqual(relaunched.lastAppliedRunID, summary.id)
        var copy = relaunched
        XCTAssertNil(ProgressionEngine.apply(summary, to: &copy), "replaying the same run after relaunch grants nothing")
    }

    func testCorruptDataFallsBackAndIsBackedUp() {
        let backing = InMemoryStore()
        let garbage = Data("not json at all".utf8)
        backing.saveData(garbage, forKey: ProfileStore.profileKey)
        let profile = ProfileStore(store: backing).load()
        XCTAssertEqual(profile, PlayerProfile())
        XCTAssertEqual(backing.loadData(forKey: ProfileStore.corruptBackupKey), garbage)
    }

    func testMissingAndInvalidFieldsAreRepaired() throws {
        let json = """
        {
          "bestScore": -50,
          "shards": -3,
          "bestDistance": 12.5,
          "unlockedItems": ["skin.gem", "skin.doesNotExist"],
          "selectedSkin": "skin.pulse",
          "selectedTheme": "skin.gem",
          "achievements": ["ach.rush", "ach.bogus"],
          "settings": { "musicVolume": 7, "soundVolume": -1, "controlScheme": "telepathy" },
          "futureField": true
        }
        """
        let backing = InMemoryStore()
        backing.saveData(Data(json.utf8), forKey: ProfileStore.profileKey)
        let profile = ProfileStore(store: backing).load()
        XCTAssertEqual(profile.bestScore, 0)
        XCTAssertEqual(profile.shards, 0)
        XCTAssertEqual(profile.bestDistance, 12.5)
        XCTAssertTrue(profile.unlockedItems.contains("skin.gem"))
        XCTAssertFalse(profile.unlockedItems.contains("skin.doesNotExist"))
        XCTAssertTrue(profile.unlockedItems.isSuperset(of: CosmeticCatalog.defaultItemIDs))
        XCTAssertEqual(profile.selectedSkin, CosmeticCatalog.defaultSkin, "not owned -> default")
        XCTAssertEqual(profile.selectedTheme, CosmeticCatalog.defaultTheme, "wrong category -> default")
        XCTAssertEqual(profile.achievements, ["ach.rush"])
        XCTAssertEqual(profile.settings.musicVolume, 1)
        XCTAssertEqual(profile.settings.soundVolume, 0)
        XCTAssertEqual(profile.settings.controlScheme, .both, "unknown scheme falls back to the default")
        XCTAssertFalse(profile.tutorialCompleted)
    }

    func testStoredControlSchemeSurvivesDefaultChange() throws {
        let backing = InMemoryStore()
        backing.saveData(Data(#"{"settings":{"controlScheme":"tap"}}"#.utf8), forKey: ProfileStore.profileKey)
        XCTAssertEqual(ProfileStore(store: backing).load().settings.controlScheme, .tap)
        XCTAssertEqual(PlayerProfile().settings.controlScheme, .both)
    }

    func testResetClearsProfile() {
        let backing = InMemoryStore()
        let store = ProfileStore(store: backing)
        var profile = PlayerProfile()
        profile.bestScore = 10
        store.save(profile)
        store.reset()
        XCTAssertEqual(store.load(), PlayerProfile())
    }

    func testUserDefaultsAdapter() {
        let suite = "cgr.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return XCTFail("no defaults") }
        defaults.saveData(Data([1, 2, 3]), forKey: "k")
        XCTAssertEqual(defaults.loadData(forKey: "k"), Data([1, 2, 3]))
        defaults.saveData(nil, forKey: "k")
        XCTAssertNil(defaults.loadData(forKey: "k"))
        defaults.removePersistentDomain(forName: suite)
    }
}

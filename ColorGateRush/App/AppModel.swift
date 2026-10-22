import SwiftUI

/// App-wide state: the persisted profile, navigation, and shared audio/haptics services.
/// Every progression change goes through `ProgressionEngine` and is saved immediately.
@MainActor
final class AppModel: ObservableObject {
    enum Screen: Equatable {
        case home, game, results, cosmetics, progress, settings
    }

    @Published private(set) var profile: PlayerProfile
    @Published private(set) var screen: Screen = .home
    @Published private(set) var gameMode: GameMode = .endless
    /// Changing the token forces a brand-new game view (and session).
    @Published private(set) var gameToken = UUID()
    @Published private(set) var lastRun: RunSummary?
    @Published private(set) var lastRewards: RunRewards?
    @Published private(set) var isActive = true

    let audio: AudioManager
    let haptics: HapticsManager
    private let store: ProfileStore
    let debug: DebugOptions

    init() {
        let defaults = UserDefaults.standard
        debug = DebugOptions(defaults: defaults)
        store = ProfileStore(store: defaults)
        if debug.resetProfile { store.reset() }
        var loaded = store.load()
        debug.applyOverrides(to: &loaded)
        profile = loaded
        audio = AudioManager()
        haptics = HapticsManager()
        applySettingsToServices()
        if let start = debug.startScreen {
            switch start {
            case "game": startGame()
            case "tutorial": startTutorial()
            case "cosmetics": screen = .cosmetics
            case "progress": screen = .progress
            case "settings": screen = .settings
            default: break
            }
        }
    }

    // MARK: - Navigation

    func navigate(_ destination: Screen) {
        audio.play(.tap)
        haptics.selection()
        withAnimation(.easeInOut(duration: 0.25)) {
            screen = destination
        }
    }

    /// Play from the home screen: first-time players get the interactive tutorial.
    func play() {
        if profile.tutorialCompleted {
            startGame()
        } else {
            startTutorial()
        }
        audio.play(.tap)
    }

    func startGame() {
        gameMode = .endless
        gameToken = UUID()
        withAnimation(.easeInOut(duration: 0.25)) { screen = .game }
    }

    func startTutorial() {
        gameMode = .tutorial
        gameToken = UUID()
        withAnimation(.easeInOut(duration: 0.25)) { screen = .game }
    }

    /// Leaving mid-run forfeits it: nothing is recorded or rewarded.
    func abandonRun() {
        navigate(.home)
    }

    func finishRun(_ summary: RunSummary) {
        guard screen == .game else { return }
        guard let rewards = ProgressionEngine.apply(summary, to: &profile) else { return }
        save()
        lastRun = summary
        lastRewards = rewards
        if rewards.isNewBest || !rewards.newAchievementIDs.isEmpty {
            audio.play(.unlock)
            haptics.success()
        }
        withAnimation(.easeInOut(duration: 0.3)) { screen = .results }
    }

    // MARK: - Progression

    @discardableResult
    func purchase(_ item: CosmeticItem) -> PurchaseResult {
        let result = ProgressionEngine.purchase(item.id, profile: &profile)
        if result == .purchased {
            ProgressionEngine.equip(item.id, profile: &profile)
            save()
            audio.play(.purchase)
            haptics.success()
        } else {
            haptics.warning()
        }
        return result
    }

    func equip(_ item: CosmeticItem) {
        guard ProgressionEngine.equip(item.id, profile: &profile) else { return }
        save()
        audio.play(.tap)
        haptics.selection()
    }

    func resetProgress() {
        let settings = profile.settings
        profile = PlayerProfile()
        profile.settings = settings
        save()
        haptics.warning()
    }

    // MARK: - Settings

    func updateSettings(_ change: (inout GameSettings) -> Void) {
        change(&profile.settings)
        profile.settings.sanitize()
        save()
        applySettingsToServices()
    }

    private func applySettingsToServices() {
        audio.apply(profile.settings)
        haptics.isEnabled = profile.settings.hapticsEnabled
    }

    var sceneStyle: SceneStyle {
        SceneStyle(skinID: profile.selectedSkin,
                   trailID: profile.selectedTrail,
                   themeID: profile.selectedTheme,
                   colorAssist: profile.settings.colorAssist,
                   reducedMotion: profile.settings.reducedMotion,
                   controlScheme: profile.settings.controlScheme)
    }

    var theme: VisualTheme { VisualTheme.theme(for: profile.selectedTheme) }

    // MARK: - Lifecycle

    func scenePhaseChanged(_ phase: ScenePhase) {
        isActive = phase == .active
        switch phase {
        case .active:
            audio.resumeAfterForeground()
        case .background:
            save()
        default:
            break
        }
    }

    private func save() {
        store.save(profile)
    }
}

/// Launch-argument switches for QA and automated screenshots. Ignored in Release builds.
struct DebugOptions {
    let resetProfile: Bool
    let skipTutorial: Bool
    let grantShards: Int
    let startScreen: String?
    let autopilot: Bool
    let overlay: Bool
    let seed: UInt64?

    init(defaults: UserDefaults) {
        #if DEBUG
        resetProfile = defaults.bool(forKey: "CGRResetProfile")
        skipTutorial = defaults.bool(forKey: "CGRSkipTutorial")
        grantShards = max(0, defaults.integer(forKey: "CGRGrantShards"))
        startScreen = defaults.string(forKey: "CGRStartScreen")
        autopilot = defaults.bool(forKey: "CGRAutopilot")
        overlay = defaults.bool(forKey: "CGRDebugOverlay")
        let seedValue = defaults.integer(forKey: "CGRSeed")
        seed = seedValue > 0 ? UInt64(seedValue) : nil
        #else
        resetProfile = false
        skipTutorial = false
        grantShards = 0
        startScreen = nil
        autopilot = false
        overlay = false
        seed = nil
        #endif
    }

    func applyOverrides(to profile: inout PlayerProfile) {
        if skipTutorial { profile.tutorialCompleted = true }
        if grantShards > 0 { profile.shards = max(profile.shards, grantShards) }
    }
}

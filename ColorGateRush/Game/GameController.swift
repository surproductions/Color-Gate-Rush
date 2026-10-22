import SpriteKit
import SwiftUI

/// Snapshot of what the SwiftUI HUD shows. Published only when it actually changes.
struct HUDState: Equatable {
    var score = 0
    var combo = 0
    var multiplier = 1
    var distance = 0
    var tier: Tier = .warmUp
    var hasShield = false
    var color: GateColor = .crimson
    var countdown: Int?
    var hint: String?
    var isTutorial = false
}

@MainActor
final class HUDModel: ObservableObject {
    @Published var state = HUDState()
}

/// Owns one run: the authoritative `GameSession`, the scene that draws it, and the bridge to
/// audio, haptics, the HUD and the app's progression.
@MainActor
final class GameController: ObservableObject {
    @Published private(set) var isPaused = false
    let hud = HUDModel()
    let mode: GameMode
    let scene: GameScene
    private(set) var session: GameSession
    private let audio: AudioManager
    private let haptics: HapticsManager
    private let onFinish: (RunSummary) -> Void
    private var finishScheduled = false

    init(mode: GameMode,
         style: SceneStyle,
         audio: AudioManager,
         haptics: HapticsManager,
         seed: UInt64? = nil,
         onFinish: @escaping (RunSummary) -> Void) {
        self.mode = mode
        self.audio = audio
        self.haptics = haptics
        self.onFinish = onFinish
        let session = GameSession(mode: mode, seed: seed ?? SeededRandom.randomSeed())
        self.session = session
        self.scene = GameScene(session: session, style: style, size: CGSize(width: 390, height: 844))
        scene.controller = self
        hud.state = makeHUD()
        haptics.prepare()
    }

    // MARK: - Commands from UI

    func requestMove(_ direction: Int) {
        guard !isPaused else { return }
        session.move(direction)
    }

    func pause() {
        guard session.isActive else { return }
        session.pause()
        scene.isPaused = true
        isPaused = true
        audio.play(.tap)
        refreshHUD()
    }

    func resume() {
        guard isPaused else { return }
        session.resume()
        isPaused = false
        scene.resetFrameClock()
        scene.isPaused = false
        audio.play(.tap)
        refreshHUD()
    }

    /// Starts a fresh run. The abandoned run is not recorded, so restarting can never farm rewards.
    func restart() {
        let fresh = GameSession(mode: mode, seed: SeededRandom.randomSeed())
        session = fresh
        finishScheduled = false
        isPaused = false
        scene.reset(with: fresh)
        refreshHUD()
    }

    /// The app moved to the background or lost focus.
    func handleInterruption() {
        if session.isActive { pause() }
    }

    // MARK: - Scene callbacks

    func sceneDidAdvance(events: [GameEvent]) {
        for event in events {
            react(to: event)
        }
        refreshHUD()
    }

    private func react(to event: GameEvent) {
        switch event {
        case .countdownTick:
            audio.play(.countdown)
        case .go:
            audio.play(.go)
            haptics.light()
        case .laneChanged:
            audio.play(.move)
        case .gatePassed(_, _, _, let combo):
            audio.playGate(level: ScoreRules.multiplier(forCombo: combo) - 1)
            haptics.light()
        case .shardCollected:
            audio.play(.shard)
        case .shieldCollected:
            audio.play(.shield)
            haptics.medium()
        case .spareShieldBonus:
            audio.play(.shard)
        case .prismPassed:
            audio.play(.prism)
            haptics.medium()
        case .milestone:
            audio.play(.milestone)
            haptics.success()
        case .tierReached:
            audio.play(.tierUp)
            haptics.success()
        case .shieldBroken:
            audio.play(.shieldBreak)
            haptics.heavy()
        case .tutorialMistake:
            audio.play(.shieldBreak)
            haptics.warning()
        case .crashed:
            audio.play(.crash)
            haptics.error()
        case .finished:
            scheduleFinish()
        case .paused, .resumed:
            break
        }
    }

    private func scheduleFinish() {
        guard !finishScheduled, let summary = session.summary() else { return }
        finishScheduled = true
        // Let the crash (or tutorial wrap-up) play out before showing results.
        let delay = summary.isTutorial ? 0.4 : 1.1
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, self.session.runID == summary.id else { return }
            self.onFinish(summary)
        }
    }

    // MARK: - HUD

    private func refreshHUD() {
        let next = makeHUD()
        if next != hud.state {
            hud.state = next
        }
    }

    private func makeHUD() -> HUDState {
        var state = HUDState()
        state.score = session.score
        state.combo = session.combo
        state.multiplier = session.multiplier
        state.distance = Int(session.distance)
        state.tier = session.tier
        state.hasShield = session.hasShield
        state.color = session.color
        state.isTutorial = session.mode == .tutorial
        if session.phase == .countdown {
            state.countdown = max(1, Int(session.countdownRemaining.rounded(.up)))
        }
        if session.mode == .tutorial, let next = session.nextUnresolvedRow, next.position - session.distance < 30 {
            state.hint = next.hint
        }
        return state
    }
}

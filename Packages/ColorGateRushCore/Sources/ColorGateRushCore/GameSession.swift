import Foundation

enum GameMode: Equatable {
    case endless
    case tutorial
}

enum HitReason: Equatable {
    case wrongColor(GateColor)
    case barrier
}

/// Things that happened during an update, consumed by presentation (visuals, audio, haptics, HUD).
enum GameEvent: Equatable {
    case countdownTick(Int)
    case go
    case laneChanged(from: Int, to: Int)
    case gatePassed(lane: Int, color: GateColor, points: Int, combo: Int)
    case shardCollected(lane: Int)
    case shieldCollected(lane: Int)
    case spareShieldBonus(lane: Int)
    case prismPassed(GateColor)
    case milestone(gates: Int)
    case tierReached(Tier)
    case shieldBroken(HitReason)
    case tutorialMistake(HitReason)
    case crashed(HitReason)
    case paused
    case resumed
    case finished
}

/// Immutable record of a completed run, used for rewards and history.
struct RunSummary: Codable, Equatable, Identifiable {
    let id: UUID
    let isTutorial: Bool
    let completedTutorial: Bool
    let score: Int
    let distance: Double
    let gatesPassed: Int
    let maxCombo: Int
    let shardsCollected: Int
    let shieldsUsed: Int
    let prismsPassed: Int
    let tierReached: Tier
    let duration: Double
    let seed: UInt64
}

/// Authoritative real-time game state. Pure logic: no rendering, timers or platform APIs.
/// The presentation layer calls `update(dt:)` once per frame and reacts to `drainEvents()`.
final class GameSession {
    enum Phase: Equatable {
        case countdown
        case running
        case paused
        case ended
    }

    static let startCountdown = 3.0
    static let resumeCountdown = 1.5
    /// How far ahead (in track units) rows are generated and shown.
    static let lookahead = 42.0
    /// Rows are kept briefly after passing so they can fly off-screen.
    static let keepBehind = 6.0
    static let tutorialSpeed = 7.0
    static let maxFrameTime = 0.1

    let mode: GameMode
    let seed: UInt64
    let runID = UUID()

    private(set) var phase: Phase = .countdown
    private(set) var countdownRemaining: Double
    private var phaseBeforePause: Phase = .running
    private var lastCountdownTick: Int

    private var source: RowSource
    private var sourceExhausted = false
    private(set) var rows: [TrackRow] = []
    private(set) var lastRowPosition: Double = 0

    private(set) var distance: Double = 0
    private(set) var lane: Int = TrackConstants.startLane
    private(set) var color: GateColor
    private(set) var hasShield = false
    private(set) var score = 0
    private(set) var combo = 0
    private(set) var maxCombo = 0
    private(set) var gatesPassed = 0
    private(set) var shardsCollected = 0
    private(set) var shieldsUsed = 0
    private(set) var prismsPassed = 0
    private(set) var tutorialMistakes = 0
    private(set) var elapsed: Double = 0
    private(set) var tier: Tier = .warmUp
    private(set) var completedTutorial = false
    private var pendingEvents: [GameEvent] = []

    var multiplier: Int { ScoreRules.multiplier(forCombo: combo) }

    var speed: Double {
        mode == .tutorial ? Self.tutorialSpeed : DifficultyModel.speed(at: distance)
    }

    var isActive: Bool { phase == .running || phase == .countdown }

    init(mode: GameMode = .endless, seed: UInt64 = SeededRandom.randomSeed(), startColor: GateColor = .crimson) {
        self.mode = mode
        self.seed = seed
        self.color = startColor
        self.countdownRemaining = Self.startCountdown
        self.lastCountdownTick = Int(Self.startCountdown.rounded(.up))
        switch mode {
        case .endless:
            source = PatternGenerator(seed: seed, startColor: startColor)
        case .tutorial:
            source = TutorialScript()
        }
        spawnRows()
        pendingEvents.append(.countdownTick(lastCountdownTick))
    }

    // MARK: - Frame update

    func update(dt rawDT: Double) {
        guard rawDT > 0, rawDT.isFinite else { return }
        let dt = min(rawDT, Self.maxFrameTime)
        switch phase {
        case .paused, .ended:
            return
        case .countdown:
            countdownRemaining -= dt
            let tick = Int(countdownRemaining.rounded(.up))
            if countdownRemaining <= 0 {
                countdownRemaining = 0
                phase = .running
                pendingEvents.append(.go)
            } else if tick < lastCountdownTick {
                lastCountdownTick = tick
                pendingEvents.append(.countdownTick(tick))
            }
        case .running:
            elapsed += dt
            distance += speed * dt
            resolveCrossedRows()
            guard phase == .running else { return }
            updateTier()
            spawnRows()
            despawnRows()
            checkTutorialEnd()
        }
    }

    func drainEvents() -> [GameEvent] {
        defer { pendingEvents.removeAll(keepingCapacity: true) }
        return pendingEvents
    }

    // MARK: - Input

    /// Moves one lane left (-1) or right (+1). Returns false when the move is not allowed.
    @discardableResult
    func move(_ direction: Int) -> Bool {
        guard isActive, direction != 0 else { return false }
        let target = min(TrackConstants.laneCount - 1, max(0, lane + (direction > 0 ? 1 : -1)))
        guard target != lane else { return false }
        pendingEvents.append(.laneChanged(from: lane, to: target))
        lane = target
        return true
    }

    func pause() {
        guard isActive else { return }
        phaseBeforePause = phase
        phase = .paused
        pendingEvents.append(.paused)
    }

    /// Resumes behind a short countdown so the player is never thrown straight back into danger.
    func resume() {
        guard phase == .paused else { return }
        phase = .countdown
        // Pausing mid-countdown keeps whatever was left if that is longer.
        countdownRemaining = phaseBeforePause == .countdown
            ? max(countdownRemaining, Self.resumeCountdown)
            : Self.resumeCountdown
        lastCountdownTick = Int(countdownRemaining.rounded(.up))
        pendingEvents.append(.resumed)
    }

    func summary() -> RunSummary? {
        guard phase == .ended else { return nil }
        return RunSummary(id: runID,
                          isTutorial: mode == .tutorial,
                          completedTutorial: completedTutorial,
                          score: score,
                          distance: distance,
                          gatesPassed: gatesPassed,
                          maxCombo: maxCombo,
                          shardsCollected: shardsCollected,
                          shieldsUsed: shieldsUsed,
                          prismsPassed: prismsPassed,
                          tierReached: tier,
                          duration: elapsed,
                          seed: seed)
    }

    /// Test hook: replaces the course with fixed rows and stops further generation.
    func replaceRowsForTesting(_ newRows: [TrackRow]) {
        rows = newRows
        sourceExhausted = true
        lastRowPosition = newRows.last?.position ?? 0
    }

    /// The nearest row the orb has not reached yet.
    var nextUnresolvedRow: TrackRow? {
        rows.first { !$0.resolved }
    }

    // MARK: - Rules

    private func resolveCrossedRows() {
        for index in rows.indices where !rows[index].resolved && rows[index].position <= distance {
            resolve(rowAt: index)
            if phase == .ended { return }
        }
    }

    private func resolve(rowAt index: Int) {
        rows[index].resolved = true
        rows[index].resolvedLane = lane
        let content = rows[index].lanes[lane]
        switch content {
        case .open:
            break
        case .gate(let gateColor):
            if gateColor == color {
                passGate(lane: lane, color: gateColor)
            } else {
                hit(.wrongColor(gateColor))
            }
        case .hazard:
            hit(.barrier)
        case .shard:
            shardsCollected += 1
            score += ScoreRules.shardPoints
            pendingEvents.append(.shardCollected(lane: lane))
        case .shield:
            if hasShield {
                score += ScoreRules.spareShieldPoints
                pendingEvents.append(.spareShieldBonus(lane: lane))
            } else {
                hasShield = true
                pendingEvents.append(.shieldCollected(lane: lane))
            }
        case .prism(let newColor):
            color = newColor
            prismsPassed += 1
            score += ScoreRules.prismPoints
            pendingEvents.append(.prismPassed(newColor))
        }
    }

    private func passGate(lane: Int, color: GateColor) {
        combo += 1
        maxCombo = max(maxCombo, combo)
        gatesPassed += 1
        let points = ScoreRules.gatePoints(combo: combo)
        score += points
        pendingEvents.append(.gatePassed(lane: lane, color: color, points: points, combo: combo))
        if ScoreRules.isMilestone(gatesPassed: gatesPassed) {
            score += ScoreRules.milestoneBonus
            pendingEvents.append(.milestone(gates: gatesPassed))
        }
    }

    private func hit(_ reason: HitReason) {
        combo = 0
        if mode == .tutorial {
            tutorialMistakes += 1
            pendingEvents.append(.tutorialMistake(reason))
            return
        }
        if hasShield {
            hasShield = false
            shieldsUsed += 1
            pendingEvents.append(.shieldBroken(reason))
            return
        }
        phase = .ended
        pendingEvents.append(.crashed(reason))
        pendingEvents.append(.finished)
    }

    private func updateTier() {
        guard mode == .endless else { return }
        let current = Tier.forDistance(distance)
        if current > tier {
            tier = current
            pendingEvents.append(.tierReached(current))
        }
    }

    private func spawnRows() {
        while !sourceExhausted && (rows.isEmpty || lastRowPosition < distance + Self.lookahead) {
            guard let row = source.nextRow() else {
                sourceExhausted = true
                break
            }
            rows.append(row)
            lastRowPosition = row.position
        }
    }

    private func despawnRows() {
        rows.removeAll { $0.resolved && $0.position < distance - Self.keepBehind }
    }

    private func checkTutorialEnd() {
        guard mode == .tutorial, sourceExhausted, distance > lastRowPosition + 6 else { return }
        completedTutorial = true
        phase = .ended
        pendingEvents.append(.finished)
    }
}

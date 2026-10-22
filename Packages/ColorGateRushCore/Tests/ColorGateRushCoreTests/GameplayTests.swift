import XCTest
@testable import ColorGateRushCore

/// A deterministic row source so rule tests control exactly what the orb meets.
private struct ScriptedSource: RowSource {
    var rows: [TrackRow]
    mutating func nextRow() -> TrackRow? {
        rows.isEmpty ? nil : rows.removeFirst()
    }
}

final class GameplayTests: XCTestCase {

    private func runningSession(seed: UInt64 = 42) -> GameSession {
        let session = GameSession(mode: .endless, seed: seed)
        session.update(dt: GameSession.startCountdown + 0.01)
        XCTAssertEqual(session.phase, .running)
        _ = session.drainEvents()
        return session
    }

    /// Advances until the next unresolved row has been crossed.
    private func advancePastNextRow(_ session: GameSession) {
        guard let row = session.nextUnresolvedRow else { return XCTFail("no row") }
        var guardCounter = 0
        while session.phase == .running && session.distance < row.position && guardCounter < 10_000 {
            session.update(dt: 1.0 / 120.0)
            guardCounter += 1
        }
    }

    private func moveTo(_ lane: Int, _ session: GameSession) {
        while session.lane < lane { session.move(1) }
        while session.lane > lane { session.move(-1) }
    }

    func testCountdownThenRunning() {
        let session = GameSession(mode: .endless, seed: 1)
        XCTAssertEqual(session.phase, .countdown)
        let start = session.distance
        session.update(dt: 1.0)
        XCTAssertEqual(session.distance, start, "orb must not move during countdown")
        session.update(dt: 1.0)
        session.update(dt: 1.01)
        XCTAssertEqual(session.phase, .running)
        let events = session.drainEvents()
        XCTAssertTrue(events.contains(.go))
        XCTAssertTrue(events.contains(.countdownTick(2)))
    }

    func testMatchingGateScoresAndBuildsCombo() {
        let session = runningSession()
        var passed = 0
        // Steer manually to a matching lane for the first several gate rows.
        for _ in 0..<40 {
            guard let row = session.nextUnresolvedRow, session.phase == .running else { break }
            if row.kind == .gate, let lane = row.lanes.firstIndex(of: .gate(session.color)) {
                let before = session.score
                let comboBefore = session.combo
                moveTo(lane, session)
                advancePastNextRow(session)
                XCTAssertEqual(session.combo, comboBefore + 1)
                XCTAssertGreaterThan(session.score, before)
                passed += 1
            } else if let lane = row.safeLanes(for: session.color).first {
                moveTo(lane, session)
                advancePastNextRow(session)
            }
        }
        XCTAssertGreaterThan(passed, 3)
        XCTAssertEqual(session.gatesPassed, passed)
        XCTAssertEqual(session.phase, .running)
    }

    func testWrongColorEndsRun() {
        let session = runningSession(seed: 7)
        for _ in 0..<60 {
            guard let row = session.nextUnresolvedRow else { break }
            if row.kind == .gate,
               let wrong = row.lanes.firstIndex(where: { if case .gate(let c) = $0 { return c != session.color }; return false }) {
                moveTo(wrong, session)
                advancePastNextRow(session)
                XCTAssertEqual(session.phase, .ended)
                let events = session.drainEvents()
                XCTAssertTrue(events.contains { if case .crashed(.wrongColor) = $0 { return true }; return false })
                XCTAssertTrue(events.contains(.finished))
                return
            }
            if let lane = row.safeLanes(for: session.color).first { moveTo(lane, session) }
            advancePastNextRow(session)
            _ = session.drainEvents()
        }
        XCTFail("never found a gate with a wrong color lane")
    }

    func testShieldAbsorbsOneHitAndResetsCombo() {
        let session = GameSession(mode: .endless, seed: 3)
        // Inject: shield, then a barrier row, then a barrier row.
        let base = session.distance
        let script = [
            TrackRow(id: 9000, position: base + 1, kind: .pickup, lanes: [.open, .shield, .open]),
            TrackRow(id: 9001, position: base + 2, kind: .hazard, lanes: [.hazard, .hazard, .hazard]),
            TrackRow(id: 9002, position: base + 3, kind: .hazard, lanes: [.hazard, .hazard, .hazard])
        ]
        session.replaceRowsForTesting(script)
        session.update(dt: GameSession.startCountdown + 0.01)
        _ = session.drainEvents()
        session.update(dt: 1.2 / session.speed)
        XCTAssertTrue(session.hasShield)
        session.update(dt: 1.0 / session.speed)
        XCTAssertFalse(session.hasShield)
        XCTAssertEqual(session.shieldsUsed, 1)
        XCTAssertEqual(session.phase, .running)
        XCTAssertEqual(session.combo, 0)
        session.update(dt: 1.0 / session.speed)
        XCTAssertEqual(session.phase, .ended)
    }

    func testGateScoresExactlyOnce() {
        let session = GameSession(mode: .endless, seed: 3)
        session.replaceRowsForTesting([
            TrackRow(id: 9000, position: 1, kind: .gate, lanes: [.gate(.crimson), .gate(.crimson), .gate(.crimson)])
        ])
        session.update(dt: GameSession.startCountdown + 0.01)
        for _ in 0..<50 { session.update(dt: 0.05) }
        XCTAssertEqual(session.gatesPassed, 1)
        XCTAssertEqual(session.score, ScoreRules.gatePoints(combo: 1))
        let gateEvents = session.drainEvents().filter { if case .gatePassed = $0 { return true }; return false }
        XCTAssertEqual(gateEvents.count, 1)
    }

    func testPauseFreezesEverything() {
        let session = runningSession()
        session.update(dt: 0.5)
        let distance = session.distance
        let score = session.score
        session.pause()
        XCTAssertEqual(session.phase, .paused)
        for _ in 0..<100 { session.update(dt: 0.1) }
        XCTAssertEqual(session.distance, distance)
        XCTAssertEqual(session.score, score)
        XCTAssertFalse(session.move(1) && session.move(-1), "input ignored while paused")
        session.resume()
        XCTAssertEqual(session.phase, .countdown)
        session.update(dt: GameSession.resumeCountdown + 0.01)
        XCTAssertEqual(session.phase, .running)
        session.update(dt: 0.1)
        XCTAssertGreaterThan(session.distance, distance)
    }

    func testNoUpdatesAfterEnd() {
        let session = GameSession(mode: .endless, seed: 5)
        session.replaceRowsForTesting([TrackRow(id: 1, position: 1, kind: .hazard, lanes: [.hazard, .hazard, .hazard])])
        session.update(dt: GameSession.startCountdown + 0.01)
        session.update(dt: 0.5)
        XCTAssertEqual(session.phase, .ended)
        let score = session.score
        let distance = session.distance
        session.update(dt: 1)
        XCTAssertFalse(session.move(-1))
        session.pause()
        XCTAssertEqual(session.phase, .ended)
        XCTAssertEqual(session.score, score)
        XCTAssertEqual(session.distance, distance)
        XCTAssertNotNil(session.summary())
    }

    func testLaneBounds() {
        let session = runningSession()
        XCTAssertTrue(session.move(-1))
        XCTAssertFalse(session.move(-1))
        XCTAssertEqual(session.lane, 0)
        XCTAssertTrue(session.move(1))
        XCTAssertTrue(session.move(1))
        XCTAssertFalse(session.move(1))
        XCTAssertEqual(session.lane, 2)
    }

    func testPrismChangesColor() {
        let session = GameSession(mode: .endless, seed: 11)
        session.replaceRowsForTesting([
            TrackRow(id: 1, position: 1, kind: .prism, lanes: Array(repeating: .prism(.azure), count: 3)),
            TrackRow(id: 2, position: 3, kind: .gate, lanes: [.gate(.crimson), .gate(.azure), .gate(.crimson)])
        ])
        session.update(dt: GameSession.startCountdown + 0.01)
        session.update(dt: 2 / session.speed)
        XCTAssertEqual(session.color, .azure)
        session.update(dt: 2 / session.speed)
        XCTAssertEqual(session.phase, .running)
        XCTAssertEqual(session.gatesPassed, 1)
    }

    func testTutorialForgivesMistakesAndCompletes() {
        let session = GameSession(mode: .tutorial, seed: 0)
        session.update(dt: GameSession.startCountdown + 0.01)
        // Never steer: the orb will hit barriers and wrong gates, which must not end the tutorial early.
        var steps = 0
        while session.phase != .ended && steps < 20_000 {
            session.update(dt: 1.0 / 60.0)
            steps += 1
        }
        XCTAssertEqual(session.phase, .ended)
        XCTAssertGreaterThan(session.tutorialMistakes, 0)
        let summary = session.summary()
        XCTAssertEqual(summary?.completedTutorial, true)
        XCTAssertEqual(summary?.isTutorial, true)
    }

    func testTutorialPerfectPlayWithAutopilot() {
        let session = GameSession(mode: .tutorial, seed: 0)
        var bot = Autopilot()
        var steps = 0
        while session.phase != .ended && steps < 20_000 {
            bot.step(session, dt: 1.0 / 60.0)
            session.update(dt: 1.0 / 60.0)
            steps += 1
        }
        XCTAssertEqual(session.tutorialMistakes, 0)
        XCTAssertEqual(session.summary()?.completedTutorial, true)
    }

    func testAutopilotSurvivesLongRuns() {
        for seed: UInt64 in [1, 2, 3, 99, 12345] {
            let session = GameSession(mode: .endless, seed: seed)
            var bot = Autopilot()
            let dt = 1.0 / 60.0
            var time = 0.0
            while time < 330 && session.phase != .ended { // 5.5 minutes: reaches the Prismatic tier
                bot.step(session, dt: dt)
                session.update(dt: dt)
                time += dt
            }
            XCTAssertNotEqual(session.phase, .ended, "autopilot crashed on seed \(seed) at \(session.distance)")
            XCTAssertEqual(session.tier, .prismatic, "seed \(seed) only reached \(session.tier)")
            XCTAssertGreaterThan(session.gatesPassed, 100)
            XCTAssertLessThan(session.rows.count, 40, "rows must be recycled")
        }
    }

    func testLargeFrameSpikeIsClamped() {
        let session = runningSession()
        let before = session.distance
        session.update(dt: 5)
        XCTAssertLessThanOrEqual(session.distance - before, session.speed * GameSession.maxFrameTime + 0.001)
        session.update(dt: .nan)
        session.update(dt: -1)
    }
}

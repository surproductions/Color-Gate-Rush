import Foundation

/// A look-ahead bot that plays a session. Used by tests to prove generated courses are
/// survivable end-to-end, and by debug builds for automated screenshots/soak testing.
struct Autopilot {
    var lookaheadRows = 4
    private var cooldown: Double = 0

    init(lookaheadRows: Int = 4) {
        self.lookaheadRows = lookaheadRows
    }

    /// Advances the bot by `dt` and performs at most one lane move on the session.
    mutating func step(_ session: GameSession, dt: Double) {
        cooldown -= dt
        guard session.isActive, cooldown <= 0 else { return }
        let upcoming = Array(session.rows.filter { !$0.resolved }.prefix(lookaheadRows))
        guard !upcoming.isEmpty else { return }
        let plan = bestPath(from: session.lane, color: session.color, rows: upcoming[...])
        guard let target = plan.first, target != session.lane else { return }
        if session.move(target > session.lane ? 1 : -1) {
            cooldown = DifficultyModel.laneSwitchTime
        }
    }

    /// Returns the lane sequence with the best (survived rows, pickups) score.
    private func bestPath(from lane: Int, color: GateColor, rows: ArraySlice<TrackRow>) -> [Int] {
        var best: (score: Int, path: [Int]) = (-1, [])
        func search(_ lane: Int, _ color: GateColor, _ index: Int, _ score: Int, _ path: [Int]) {
            guard index < rows.endIndex else {
                if score > best.score { best = (score, path) }
                return
            }
            let row = rows[index]
            var advanced = false
            for next in 0..<TrackConstants.laneCount where abs(next - lane) <= 2 {
                let content = row.lanes[next]
                guard content.isSafe(for: color) else { continue }
                advanced = true
                let bonus = content.isPickup ? 3 : 0
                let travelPenalty = abs(next - lane)
                search(next, row.colorAfter(color), index + 1, score + 100 + bonus - travelPenalty, path + [next])
            }
            if !advanced, score > best.score {
                best = (score, path)
            }
        }
        search(lane, color, rows.startIndex, 0, [])
        return best.path
    }
}

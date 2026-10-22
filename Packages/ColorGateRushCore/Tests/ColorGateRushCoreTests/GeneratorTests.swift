import XCTest
@testable import ColorGateRushCore

final class GeneratorTests: XCTestCase {

    private func generate(seed: UInt64, count: Int) -> [TrackRow] {
        var generator = PatternGenerator(seed: seed)
        var rows: [TrackRow] = []
        for _ in 0..<count {
            guard let row = generator.nextRow() else { break }
            rows.append(row)
        }
        return rows
    }

    func testSameSeedReproducesCourse() {
        let a = generate(seed: 2024, count: 400)
        let b = generate(seed: 2024, count: 400)
        XCTAssertEqual(a, b)
        let c = generate(seed: 2025, count: 400)
        XCTAssertNotEqual(a.map(\.lanes), c.map(\.lanes))
    }

    func testRowsAreOrderedWithUniqueIDsAndThreeLanes() {
        let rows = generate(seed: 9, count: 600)
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
        for (prev, next) in zip(rows, rows.dropFirst()) {
            XCTAssertGreaterThan(next.position, prev.position)
        }
        XCTAssertTrue(rows.allSatisfy { $0.lanes.count == TrackConstants.laneCount })
    }

    /// The core fairness property, checked with real speeds: from every lane a player could
    /// be alive in, a safe lane of the next row is reachable in the time available.
    func testNoImpossibleTransitionsAcrossManySeeds() {
        for seed in UInt64(1)...60 {
            let rows = generate(seed: seed, count: 700)
            var color = GateColor.crimson
            var alive: Set<Int> = [TrackConstants.startLane]
            var previousPosition: Double?
            for row in rows {
                let reach: Int
                if let prev = previousPosition {
                    // Worst case: the whole gap is crossed at the (higher) speed of the later row.
                    let time = (row.position - prev) / DifficultyModel.speed(at: row.position)
                    XCTAssertGreaterThanOrEqual(time, DifficultyModel.minimumFairGap - 1e-9,
                                                "seed \(seed) row \(row.id) gap too small")
                    reach = DifficultyModel.reach(forGapTime: time)
                } else {
                    reach = TrackConstants.laneCount
                }
                let safe = row.safeLanes(for: color)
                for origin in alive {
                    let ok = safe.contains { abs($0 - origin) <= reach }
                    XCTAssertTrue(ok, "seed \(seed) row \(row.id): lane \(origin) is trapped (\(row.lanes))")
                }
                alive = Set(safe.filter { lane in alive.contains { abs($0 - lane) <= reach } })
                XCTAssertFalse(alive.isEmpty)
                color = row.colorAfter(color)
                previousPosition = row.position
            }
        }
    }

    func testGateRowsAlwaysContainCurrentColorAndUseTierPalette() {
        var generator = PatternGenerator(seed: 77)
        var color = GateColor.crimson
        for _ in 0..<1500 {
            guard let row = generator.nextRow() else { break }
            let palette = Set(DifficultyModel.parameters(at: row.position).colors)
            if row.kind == .gate {
                XCTAssertTrue(row.lanes.contains(.gate(color)))
            }
            for lane in row.lanes {
                if case .gate(let c) = lane { XCTAssertTrue(palette.contains(c) || c == color) }
                if case .prism(let c) = lane {
                    XCTAssertNotEqual(c, color, "prisms must change the color")
                    XCTAssertTrue(palette.contains(c))
                }
            }
            if row.kind == .prism {
                XCTAssertEqual(Set(row.lanes.map { "\($0)" }).count, 1, "prism rows span all lanes with one color")
            }
            color = row.colorAfter(color)
        }
    }

    func testPrismsAppearRegularlyAndShieldsAreRare() {
        let rows = generate(seed: 5, count: 1000)
        let prisms = rows.filter { $0.kind == .prism }.count
        let shields = rows.filter { $0.lanes.contains(.shield) }.count
        XCTAssertGreaterThan(prisms, 40)
        XCTAssertLessThan(shields, 1000 / PatternGenerator.shieldCooldownRows + 1)
        XCTAssertFalse(rows.prefix(8).contains { $0.lanes.contains(.shield) }, "no shield in the opening")
    }

    func testDifficultyIsMonotonicAndCapped() {
        var lastSpeed = 0.0
        var lastGap = Double.infinity
        var lastTier = Tier.warmUp
        for step in 0...2000 {
            let d = Double(step) * 5
            let p = DifficultyModel.parameters(at: d)
            XCTAssertGreaterThanOrEqual(p.speed, lastSpeed)
            XCTAssertLessThanOrEqual(p.gapTime, lastGap)
            XCTAssertGreaterThanOrEqual(p.tier, lastTier)
            XCTAssertLessThanOrEqual(p.speed, DifficultyModel.maxSpeed)
            XCTAssertGreaterThanOrEqual(p.gapTime, DifficultyModel.minGapTime)
            lastSpeed = p.speed
            lastGap = p.gapTime
            lastTier = p.tier
        }
        XCTAssertGreaterThanOrEqual(DifficultyModel.minGapTime, DifficultyModel.minimumFairGap)
        XCTAssertEqual(Tier.forDistance(0), .warmUp)
        XCTAssertEqual(Tier.forDistance(350), .rush)
        XCTAssertEqual(Tier.forDistance(1999), .overdrive)
        XCTAssertEqual(Tier.forDistance(1_000_000), .prismatic)
        XCTAssertEqual(DifficultyModel.parameters(at: 0).colors.count, 2)
        XCTAssertEqual(DifficultyModel.parameters(at: 5000).colors.count, 5)
    }

    func testOpeningIsGentle() {
        let rows = generate(seed: 31, count: 2)
        XCTAssertEqual(rows[0].kind, .pickup)
        XCTAssertFalse(rows[0].lanes.contains(.hazard))
        XCTAssertGreaterThanOrEqual(rows[0].position, 20, "first row leaves time after the countdown")
    }

    func testSeededRandomHelpers() {
        var rng = SeededRandom(seed: 1)
        for _ in 0..<1000 {
            let u = rng.unit()
            XCTAssertTrue(u >= 0 && u < 1)
            XCTAssertTrue((-1...1).contains(rng.int(in: -1...1)))
        }
        XCTAssertEqual(rng.weightedIndex([0, 0, 5]), 2)
        XCTAssertEqual(Set(rng.shuffled([1, 2, 3, 4])), [1, 2, 3, 4])
    }
}

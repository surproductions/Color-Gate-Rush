import Foundation

/// SplitMix64: tiny, fast and fully deterministic across platforms, so a seed always
/// reproduces the same course (useful for debugging and tests).
struct SeededRandom: RandomNumberGenerator {
    private(set) var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform value in [0, 1).
    mutating func unit() -> Double {
        Double(next() >> 11) / 9_007_199_254_740_992.0 // 2^53
    }

    mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    mutating func pick<T>(_ items: [T]) -> T {
        precondition(!items.isEmpty, "pick from empty array")
        return items[int(in: 0...(items.count - 1))]
    }

    mutating func shuffled<T>(_ items: [T]) -> [T] {
        var result = items
        guard result.count > 1 else { return result }
        for i in stride(from: result.count - 1, to: 0, by: -1) {
            let j = int(in: 0...i)
            result.swapAt(i, j)
        }
        return result
    }

    /// Picks an index according to non-negative weights.
    mutating func weightedIndex(_ weights: [Double]) -> Int {
        let total = weights.reduce(0) { $0 + max(0, $1) }
        guard total > 0 else { return 0 }
        var roll = unit() * total
        for (index, weight) in weights.enumerated() {
            roll -= max(0, weight)
            if roll < 0 { return index }
        }
        return weights.count - 1
    }

    static func randomSeed() -> UInt64 {
        UInt64.random(in: 1...UInt64.max)
    }
}

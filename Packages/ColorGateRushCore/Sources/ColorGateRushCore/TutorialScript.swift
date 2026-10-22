import Foundation

/// A short, hand-authored course that teaches one rule per row.
/// In tutorial mode mistakes never end the run; the session reports them instead.
struct TutorialScript: RowSource {
    static let steps: [(kind: RowKind, lanes: [LaneContent], hint: String)] = [
        (.hazard, [.open, .hazard, .hazard], "Tap the left or right side of the screen to switch lanes"),
        (.hazard, [.hazard, .hazard, .open], "Dodge the striped barriers"),
        (.gate, [.gate(.amber), .gate(.crimson), .gate(.amber)], "Fly through the gate that matches your orb's color and shape"),
        (.gate, [.gate(.crimson), .gate(.amber), .gate(.amber)], "Chain matches to build your combo multiplier"),
        (.pickup, [.shard, .shard, .shard], "Grab shards to unlock new orbs, trails and themes"),
        (.prism, [.prism(.azure), .prism(.azure), .prism(.azure)], "Prisms change your orb's color"),
        (.gate, [.gate(.crimson), .gate(.crimson), .gate(.azure)], "Now match your new color!"),
        (.pickup, [.open, .shield, .open], "Shields absorb one mistake"),
        (.gate, [.gate(.azure), .gate(.amber), .gate(.crimson)], "You're ready. Go rush!")
    ]

    static let firstPosition = 22.0
    static let spacing = 17.0

    private var index = 0

    mutating func nextRow() -> TrackRow? {
        guard index < Self.steps.count else { return nil }
        let step = Self.steps[index]
        let row = TrackRow(id: index,
                           position: Self.firstPosition + Double(index) * Self.spacing,
                           kind: step.kind,
                           lanes: step.lanes,
                           hint: step.hint)
        index += 1
        return row
    }
}

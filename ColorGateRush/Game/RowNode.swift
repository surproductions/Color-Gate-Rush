import SpriteKit

/// Visual for one `TrackRow`. Pooled and reconfigured instead of re-created.
final class RowNode: SKNode {
    private(set) var rowID = -1
    private(set) var laneSprites: [SKSpriteNode] = []
    let prismBand = SKSpriteNode()
    var feedbackApplied = false
    private static let spinKey = "spin"

    override init() {
        super.init()
        for _ in 0..<TrackConstants.laneCount {
            let sprite = SKSpriteNode()
            laneSprites.append(sprite)
            addChild(sprite)
        }
        addChild(prismBand)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(row: TrackRow, textures: TextureFactory, laneSpacing: CGFloat, spriteScale: CGFloat) {
        rowID = row.id
        feedbackApplied = false
        alpha = 1
        for (lane, sprite) in laneSprites.enumerated() {
            sprite.removeAllActions()
            sprite.alpha = 1
            sprite.zRotation = 0
            sprite.position = CGPoint(x: CGFloat(lane - 1) * laneSpacing, y: 0)
            sprite.setScale(spriteScale)
            sprite.isHidden = false
            switch row.lanes[lane] {
            case .open, .prism:
                sprite.isHidden = true
            case .gate(let color):
                sprite.texture = textures.gate(color)
                sprite.size = TextureFactory.gateSize
            case .hazard:
                sprite.texture = textures.hazard()
                sprite.size = TextureFactory.hazardSize
            case .shard:
                sprite.texture = textures.shard()
                sprite.size = TextureFactory.shardSize
                sprite.position.y = 6
                let bob = SKAction.sequence([.moveBy(x: 0, y: 8, duration: 0.45), .moveBy(x: 0, y: -8, duration: 0.45)])
                bob.timingMode = .easeInEaseOut
                sprite.run(.repeatForever(bob), withKey: Self.spinKey)
            case .shield:
                sprite.texture = textures.shield()
                sprite.size = TextureFactory.shieldSize
                sprite.position.y = 6
                let pulse = SKAction.sequence([.scale(to: spriteScale * 1.12, duration: 0.4), .scale(to: spriteScale, duration: 0.4)])
                sprite.run(.repeatForever(pulse), withKey: Self.spinKey)
            }
        }
        if row.kind == .prism, case .prism(let color)? = row.lanes.first {
            prismBand.isHidden = false
            prismBand.removeAllActions()
            prismBand.alpha = 1
            prismBand.texture = textures.prismBand(color)
            prismBand.size = TextureFactory.prismSize
            prismBand.setScale(laneSpacing * 3 / TextureFactory.prismSize.width)
        } else {
            prismBand.isHidden = true
        }
    }

    func recycle() {
        removeAllActions()
        laneSprites.forEach { $0.removeAllActions() }
        prismBand.removeAllActions()
        removeFromParent()
        rowID = -1
    }
}

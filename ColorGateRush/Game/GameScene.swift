import SpriteKit
import UIKit

/// Cosmetic and accessibility choices that shape how a run is drawn.
struct SceneStyle {
    var skinID: String
    var trailID: String
    var themeID: String
    var colorAssist: Bool
    var reducedMotion: Bool
    var controlScheme: ControlScheme
}

/// Renders a `GameSession` with a pseudo-3D perspective and turns touches into lane moves.
/// The scene never decides outcomes: all rules live in `GameSession`.
final class GameScene: SKScene {
    weak var controller: GameController?
    private(set) var session: GameSession
    private let style: SceneStyle
    private let theme: VisualTheme
    private let textures: TextureFactory
    #if DEBUG
    var autopilot: Autopilot?
    var autopilotSeconds: Double = 0
    private let debugLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    var showsDebugOverlay = false
    #endif

    // Layers
    private let cam = SKCameraNode()
    private let world = SKNode()
    private let sky = SKSpriteNode()
    private let trackFloor = SKSpriteNode()
    private let flash = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
    private var stars: [(node: SKSpriteNode, depth: CGFloat)] = []
    private var dashes: [(node: SKSpriteNode, offset: CGFloat, index: Int)] = []
    private var speedLines: [SKSpriteNode] = []

    // Player
    private let orb = SKSpriteNode()
    private let orbSymbol = SKSpriteNode()
    private let shieldBubble = SKSpriteNode()
    private var trail: SKEmitterNode?
    private var trailBaseRate: CGFloat = 0
    private var visualLane: CGFloat = CGFloat(TrackConstants.startLane)
    private var displayedColor: GateColor
    private var orbTime: CGFloat = 0

    // Rows
    private var rowNodes: [Int: RowNode] = [:]
    private var rowPool: [RowNode] = []
    private var liveIDs = Set<Int>()
    private var popupPool: [SKLabelNode] = []
    private var lastUpdateTime: TimeInterval?

    // Geometry (recomputed on resize)
    private var playerY: CGFloat = 0
    private var horizonY: CGFloat = 0
    private var laneSpacing: CGFloat = 100
    private var spriteScale: CGFloat = 1
    private var builtForSize: CGSize = .zero
    private let cameraDepth: Double = 18
    private let dashSpacing: Double = 7
    private let dashCount = 7

    private var swipeStarts: [ObjectIdentifier: CGPoint] = [:]

    init(session: GameSession, style: SceneStyle, size: CGSize) {
        self.session = session
        self.style = style
        self.theme = VisualTheme.theme(for: style.themeID)
        self.textures = TextureFactory(colorAssist: style.colorAssist)
        self.displayedColor = session.color
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = theme.skyTop
        setUpNodes()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Setup

    private func setUpNodes() {
        addChild(cam)
        camera = cam
        addChild(world)

        sky.zPosition = -100
        trackFloor.zPosition = -50
        world.addChild(sky)
        world.addChild(trackFloor)

        let starCount = style.reducedMotion ? 24 : 48
        for i in 0..<starCount {
            let star = SKSpriteNode(texture: textures.particle())
            star.color = theme.star
            star.colorBlendFactor = 1
            let depth = CGFloat(0.25 + 0.75 * Double((i * 37) % 100) / 100)
            star.setScale(0.18 + depth * 0.25)
            star.alpha = 0.25 + depth * 0.5
            star.zPosition = -90
            world.addChild(star)
            stars.append((star, depth))
        }

        for divider in 0..<4 {
            let offset: CGFloat = [-1.5, -0.5, 0.5, 1.5][divider]
            for i in 0..<dashCount {
                let dash = SKSpriteNode(texture: textures.dash())
                dash.color = divider == 0 || divider == 3 ? theme.edge : theme.lane.withAlphaComponent(1)
                dash.colorBlendFactor = 1
                dash.blendMode = .add
                dash.zPosition = -40
                world.addChild(dash)
                dashes.append((dash, offset, i))
            }
        }

        if !style.reducedMotion {
            for _ in 0..<10 {
                let line = SKSpriteNode(texture: textures.streak())
                line.alpha = 0
                line.blendMode = .add
                line.zPosition = -30
                world.addChild(line)
                speedLines.append(line)
            }
        }

        orb.texture = textures.orb(skin: style.skinID)
        orb.size = TextureFactory.orbSize
        orb.colorBlendFactor = 1
        orb.color = displayedColor.uiColor
        orb.zPosition = 100
        orbSymbol.texture = textures.orbSymbol(displayedColor.symbol)
        orbSymbol.size = CGSize(width: 30, height: 30)
        orbSymbol.zPosition = 1
        orb.addChild(orbSymbol)
        shieldBubble.texture = textures.shieldBubble()
        shieldBubble.size = CGSize(width: 110, height: 110)
        shieldBubble.zPosition = 2
        shieldBubble.isHidden = true
        shieldBubble.run(.repeatForever(.rotate(byAngle: .pi, duration: 3)))
        orb.addChild(shieldBubble)
        world.addChild(orb)
        if style.skinID == "skin.star" {
            orb.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 2.5)), withKey: "spin")
        }

        let emitter = makeTrail()
        trailBaseRate = emitter.particleBirthRate
        emitter.zPosition = 95
        emitter.targetNode = world
        world.addChild(emitter)
        trail = emitter

        flash.alpha = 0
        flash.zPosition = 500
        flash.blendMode = .add
        cam.addChild(flash)

        for _ in 0..<10 {
            let label = SKLabelNode(fontNamed: "AvenirNext-HeavyItalic")
            label.fontSize = 26
            label.isHidden = true
            label.zPosition = 400
            world.addChild(label)
            popupPool.append(label)
        }

        #if DEBUG
        debugLabel.fontSize = 11
        debugLabel.numberOfLines = 0
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.zPosition = 900
        debugLabel.fontColor = .green
        cam.addChild(debugLabel)
        #endif
    }

    private func makeTrail() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = textures.particle(square: style.trailID == "trail.pixel")
        emitter.particleBlendMode = .add
        emitter.emissionAngle = -.pi / 2
        emitter.particleColorBlendFactor = 1
        emitter.particleColor = displayedColor.uiColor
        let density: CGFloat = style.reducedMotion ? 0.5 : 1
        switch style.trailID {
        case "trail.ribbon":
            emitter.particleBirthRate = 260 * density
            emitter.particleLifetime = 0.28
            emitter.particleSpeed = 520
            emitter.particleScale = 1.6
            emitter.particleScaleSpeed = -4.5
            emitter.particleAlpha = 0.65
            emitter.particleAlphaSpeed = -2.2
            emitter.particlePositionRange = CGVector(dx: 8, dy: 0)
        case "trail.bubble":
            emitter.particleBirthRate = 36 * density
            emitter.particleLifetime = 0.9
            emitter.particleSpeed = 300
            emitter.particleSpeedRange = 120
            emitter.emissionAngleRange = 0.5
            emitter.particleScale = 0.9
            emitter.particleScaleRange = 0.6
            emitter.particleScaleSpeed = -0.6
            emitter.particleAlpha = 0.7
            emitter.particleAlphaSpeed = -0.8
        case "trail.pixel":
            emitter.particleBirthRate = 70 * density
            emitter.particleLifetime = 0.5
            emitter.particleSpeed = 420
            emitter.particleSpeedRange = 80
            emitter.emissionAngleRange = 0.3
            emitter.particleScale = 0.7
            emitter.particleScaleSpeed = -1.2
            emitter.particleAlpha = 0.9
            emitter.particleAlphaSpeed = -1.6
        case "trail.rainbow":
            emitter.particleBirthRate = 140 * density
            emitter.particleLifetime = 0.5
            emitter.particleSpeed = 460
            emitter.particleScale = 1.0
            emitter.particleScaleSpeed = -1.8
            emitter.particleAlpha = 0.85
            emitter.particleAlphaSpeed = -1.6
            emitter.particlePositionRange = CGVector(dx: 14, dy: 0)
            let colors = GateColor.allCases.map(\.uiColor)
            let times = colors.indices.map { NSNumber(value: Double($0) / Double(colors.count - 1)) }
            emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: colors, times: times)
        default: // sparks
            emitter.particleBirthRate = 90 * density
            emitter.particleLifetime = 0.45
            emitter.particleSpeed = 420
            emitter.particleSpeedRange = 120
            emitter.emissionAngleRange = 0.35
            emitter.particleScale = 0.75
            emitter.particleScaleRange = 0.3
            emitter.particleScaleSpeed = -1.4
            emitter.particleAlpha = 0.95
            emitter.particleAlphaSpeed = -2
        }
        return emitter
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        layoutIfNeeded()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutIfNeeded()
    }

    // MARK: - Layout & projection

    private func layoutIfNeeded() {
        guard size.width > 1, size.height > 1, size != builtForSize else { return }
        builtForSize = size
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
        playerY = size.height * 0.2
        horizonY = size.height * 0.79
        let trackWidth = min(size.width * 0.94, 460)
        laneSpacing = trackWidth / CGFloat(TrackConstants.laneCount)
        spriteScale = laneSpacing / TextureFactory.laneDesignWidth
        orb.setScale(spriteScale)

        sky.texture = textures.sky(size: size, theme: theme, horizonFromTop: size.height - horizonY)
        sky.size = size
        sky.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // Track floor from the bottom of the screen up to the far end of the visible course.
        let farZ = GameSession.lookahead
        let nearZ = depthForScreenY(-10)
        func imagePoint(_ laneOffset: CGFloat, _ z: Double) -> CGPoint {
            let p = project(z: z, laneOffset: laneOffset)
            return CGPoint(x: p.point.x, y: size.height - p.point.y)
        }
        let corners = [imagePoint(-1.5, nearZ), imagePoint(1.5, nearZ), imagePoint(1.5, farZ), imagePoint(-1.5, farZ)]
        let dividers = [CGFloat(-0.5), 0.5].map { (imagePoint($0, nearZ), imagePoint($0, farZ)) }
        trackFloor.texture = textures.track(size: size, theme: theme, corners: corners, dividers: dividers)
        trackFloor.size = size
        trackFloor.position = sky.position

        flash.size = CGSize(width: size.width * 1.2, height: size.height * 1.2)
        for (star, _) in stars {
            star.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
        }
        #if DEBUG
        debugLabel.position = CGPoint(x: -size.width / 2 + 10, y: size.height / 2 - 60)
        #endif
        for node in rowNodes.values {
            node.recycle()
        }
        rowNodes.removeAll()
        sync(dt: 0)
    }

    private func perspectiveScale(_ z: Double) -> Double {
        cameraDepth / (cameraDepth + max(z, -cameraDepth * 0.6))
    }

    /// Maps a track depth `z` (units ahead of the orb) and lane offset (-1.5...1.5) to the screen.
    private func project(z: Double, laneOffset: CGFloat) -> (point: CGPoint, scale: CGFloat) {
        let s = perspectiveScale(z)
        let far = perspectiveScale(GameSession.lookahead)
        let t = (1 - s) / (1 - far)
        let y = playerY + (horizonY - playerY) * CGFloat(t)
        let x = size.width / 2 + laneOffset * laneSpacing * CGFloat(s)
        return (CGPoint(x: x, y: y), CGFloat(s))
    }

    /// Inverse of `project` for the y axis.
    private func depthForScreenY(_ y: CGFloat) -> Double {
        let far = perspectiveScale(GameSession.lookahead)
        let t = Double((y - playerY) / (horizonY - playerY))
        let s = 1 - t * (1 - far)
        return cameraDepth / s - cameraDepth
    }

    // MARK: - Session control

    func reset(with newSession: GameSession) {
        session = newSession
        for node in rowNodes.values {
            node.recycle()
            rowPool.append(node)
        }
        rowNodes.removeAll()
        visualLane = CGFloat(newSession.lane)
        setOrbColor(newSession.color, animated: false)
        shieldBubble.isHidden = true
        orb.isHidden = false
        orb.alpha = 1
        orb.setScale(spriteScale)
        trail?.resetSimulation()
        trail?.particleBirthRate = trailBaseRate
        lastUpdateTime = nil
        isPaused = false
        sync(dt: 0)
    }

    /// Call after unpausing so the time spent paused is not simulated.
    func resetFrameClock() {
        lastUpdateTime = nil
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime.map { min(currentTime - $0, 0.25) } ?? 0
        lastUpdateTime = currentTime

        if session.phase == .paused {
            // SpriteKit unpauses scenes when the app returns to the foreground; keep it frozen.
            isPaused = true
            return
        }

        #if DEBUG
        if autopilotSeconds > 0 && session.elapsed > autopilotSeconds {
            autopilot = nil
        }
        if var bot = autopilot {
            bot.step(session, dt: dt)
            autopilot = bot
        }
        #endif

        session.update(dt: dt)
        let events = session.drainEvents()
        for event in events {
            present(event)
        }
        controller?.sceneDidAdvance(events: events)
        sync(dt: dt)
    }

    private func sync(dt: Double) {
        guard builtForSize != .zero else { return }
        let speed = session.phase == .running ? session.speed : 0

        // Orb
        let laneTarget = CGFloat(session.lane)
        let follow = CGFloat(min(1, dt * 22))
        visualLane += (laneTarget - visualLane) * (dt == 0 ? 1 : follow)
        orbTime += CGFloat(dt)
        let bob = style.reducedMotion ? 0 : sin(orbTime * 6) * 3
        let orbPoint = project(z: 0, laneOffset: visualLane - 1).point
        orb.position = CGPoint(x: orbPoint.x, y: orbPoint.y + bob)
        orb.zRotation = style.skinID == "skin.star" ? orb.zRotation : (laneTarget - visualLane) * -0.25
        trail?.position = CGPoint(x: orb.position.x, y: orb.position.y - 14 * spriteScale)
        trail?.particleSpeed = CGFloat(260 + speed * 22)
        shieldBubble.isHidden = !session.hasShield
        if session.color != displayedColor {
            setOrbColor(session.color, animated: true)
        }

        syncRows()
        syncDecor(dt: dt, speed: speed)

        #if DEBUG
        if showsDebugOverlay {
            debugLabel.text = String(format: "tier %@  speed %.1f  dist %.0f\nseed %llu  rows %d  nodes %d  phase %@",
                                     session.tier.name, session.speed, session.distance, session.seed,
                                     session.rows.count, rowNodes.count, "\(session.phase)")
        }
        #endif
    }

    private func syncRows() {
        liveIDs.removeAll(keepingCapacity: true)
        let lookahead = GameSession.lookahead
        for row in session.rows {
            liveIDs.insert(row.id)
            let node = rowNodes[row.id] ?? attachNode(for: row)
            let z = row.position - session.distance
            let projected = project(z: z, laneOffset: 0)
            node.position = projected.point
            node.setScale(projected.scale)
            node.zPosition = CGFloat(100 - z)
            let fadeIn = min(1, max(0, (lookahead - z) / 8))
            let fadeOut = min(1, max(0, (z + GameSession.keepBehind) / 3))
            node.alpha = CGFloat(min(fadeIn, fadeOut))
            if row.resolved && !node.feedbackApplied {
                node.feedbackApplied = true
                applyResolvedFeedback(row: row, node: node)
            }
        }
        for (id, node) in rowNodes where !liveIDs.contains(id) {
            node.recycle()
            rowPool.append(node)
            rowNodes[id] = nil
        }
    }

    private func attachNode(for row: TrackRow) -> RowNode {
        let node = rowPool.popLast() ?? RowNode()
        node.configure(row: row, textures: textures, laneSpacing: laneSpacing, spriteScale: spriteScale)
        world.addChild(node)
        rowNodes[row.id] = node
        return node
    }

    private func applyResolvedFeedback(row: TrackRow, node: RowNode) {
        guard let lane = row.resolvedLane else { return }
        let sprite = node.laneSprites[lane]
        switch row.lanes[lane] {
        case .shard, .shield:
            sprite.removeAllActions()
            sprite.run(.group([.scale(to: spriteScale * 1.8, duration: 0.15), .fadeOut(withDuration: 0.15)]))
        case .gate(let color) where color == session.color:
            sprite.run(.group([.scale(to: spriteScale * 1.35, duration: 0.2), .fadeOut(withDuration: 0.2)]))
        case .prism:
            node.prismBand.run(.group([.scaleX(to: node.prismBand.xScale * 1.15, duration: 0.2), .fadeOut(withDuration: 0.25)]))
        default:
            break
        }
    }

    private func syncDecor(dt: Double, speed: Double) {
        // Lane dashes scroll toward the player to sell speed.
        let phase = session.distance.truncatingRemainder(dividingBy: dashSpacing)
        let dashScale = spriteScale
        for (dash, offset, index) in dashes {
            let z = Double(index) * dashSpacing - phase
            let p = project(z: z, laneOffset: offset)
            dash.position = p.point
            dash.yScale = p.scale * dashScale * 0.9
            dash.xScale = p.scale * dashScale * (offset.magnitude > 1 ? 0.8 : 0.45)
            let fade = min(1, max(0, (GameSession.lookahead - z) / 10)) * min(1, max(0, (z + 3) / 3))
            dash.alpha = CGFloat(fade) * (offset.magnitude > 1 ? 0.9 : 0.35)
        }

        // Stars drift downward, faster as the run speeds up.
        let drift = CGFloat(dt * (4 + speed * 2.2))
        for (star, depth) in stars {
            star.position.y -= drift * depth * 3
            if star.position.y < 0 {
                star.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + 4)
            }
        }

        // Speed lines fade in once the pace picks up.
        guard !speedLines.isEmpty else { return }
        let intensity = CGFloat(max(0, min(1, (speed - 11) / 5)))
        for line in speedLines {
            if line.alpha <= 0.01 && intensity > 0 && CGFloat.random(in: 0...1) < intensity * CGFloat(dt) * 6 {
                let side: CGFloat = Bool.random() ? -1 : 1
                line.position = CGPoint(x: size.width / 2 + side * CGFloat.random(in: size.width * 0.3...size.width * 0.5),
                                        y: CGFloat.random(in: size.height * 0.3...size.height))
                line.yScale = CGFloat.random(in: 1.5...3)
                line.alpha = 0.5 * intensity
                line.color = theme.star
            }
            if line.alpha > 0 {
                line.position.y -= CGFloat(dt) * 1600
                line.alpha -= CGFloat(dt) * 1.4
                if line.position.y < -100 { line.alpha = 0 }
            }
        }
    }

    // MARK: - Event visuals

    private func present(_ event: GameEvent) {
        switch event {
        case .gatePassed(_, let color, let points, let combo):
            burst(at: orb.position, color: color.uiColor, count: 18)
            popup("+\(points)", color: color.uiColor)
            pulseOrb(1.25)
            if combo > 1 && ScoreRules.multiplier(forCombo: combo) > ScoreRules.multiplier(forCombo: combo - 1) {
                banner("x\(ScoreRules.multiplier(forCombo: combo)) COMBO", subtitle: nil, color: color.uiColor, small: true)
            }
        case .shardCollected:
            burst(at: orb.position, color: UIColor(hex: 0x9FF6FF), count: 10)
            popup("+\(ScoreRules.shardPoints)", color: UIColor(hex: 0xBFF8FF))
        case .shieldCollected:
            burst(at: orb.position, color: .white, count: 16)
            shockwave(color: .white)
        case .spareShieldBonus:
            popup("+\(ScoreRules.spareShieldPoints)", color: .white)
        case .prismPassed(let color):
            shockwave(color: color.uiColor)
            screenFlash(color.uiColor, alpha: 0.28)
            pulseOrb(1.5)
        case .milestone(let gates):
            banner("\(gates) GATES", subtitle: "+\(ScoreRules.milestoneBonus) BONUS", color: .white, small: false)
        case .tierReached(let tier):
            let previous = Tier(rawValue: tier.rawValue - 1)?.colorCount ?? tier.colorCount
            if tier.colorCount > previous, let added = GateColor.palette(count: tier.colorCount).last {
                banner(tier.name.uppercased(), subtitle: "NEW COLOR: \(added.displayName.uppercased())", color: added.uiColor, small: false)
            } else {
                banner(tier.name.uppercased(), subtitle: "SPEED UP", color: .white, small: false)
            }
            screenFlash(theme.glow, alpha: 0.25)
        case .shieldBroken:
            burst(at: orb.position, color: .white, count: 30)
            shake(intensity: 10)
            screenFlash(UIColor(hex: 0xFF4466), alpha: 0.3)
        case .tutorialMistake(let reason):
            shake(intensity: 6)
            screenFlash(UIColor(hex: 0xFF4466), alpha: 0.22)
            switch reason {
            case .barrier: popup("BARRIER!", color: UIColor(hex: 0xFF6B81))
            case .wrongColor: popup("WRONG COLOR!", color: UIColor(hex: 0xFF6B81))
            }
        case .crashed:
            crash()
        case .laneChanged:
            if !style.reducedMotion { pulseOrb(0.88) }
        case .go:
            pulseOrb(1.3)
        case .countdownTick, .paused, .resumed, .finished:
            break
        }
    }

    private func setOrbColor(_ color: GateColor, animated: Bool) {
        displayedColor = color
        orbSymbol.texture = textures.orbSymbol(color.symbol)
        if style.trailID != "trail.rainbow" {
            trail?.particleColor = color.uiColor
        }
        if animated {
            orb.run(.colorize(with: color.uiColor, colorBlendFactor: 1, duration: 0.12))
        } else {
            orb.color = color.uiColor
        }
    }

    private func pulseOrb(_ amount: CGFloat) {
        let base = spriteScale
        orb.removeAction(forKey: "pulse")
        let up = SKAction.scale(to: base * amount, duration: 0.07)
        let down = SKAction.scale(to: base, duration: 0.16)
        down.timingMode = .easeOut
        orb.run(.sequence([up, down]), withKey: "pulse")
    }

    private func burst(at point: CGPoint, color: UIColor, count: Int) {
        let n = style.reducedMotion ? count / 2 : count
        guard n > 0 else { return }
        let emitter = SKEmitterNode()
        emitter.particleTexture = textures.particle()
        emitter.particleBlendMode = .add
        emitter.numParticlesToEmit = n
        emitter.particleBirthRate = CGFloat(n) * 40
        emitter.particleLifetime = 0.5
        emitter.particleLifetimeRange = 0.2
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 260
        emitter.particleSpeedRange = 140
        emitter.particleScale = 0.8
        emitter.particleScaleSpeed = -1.4
        emitter.particleAlphaSpeed = -1.8
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.position = point
        emitter.zPosition = 300
        world.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 0.9), .removeFromParent()]))
    }

    private func shockwave(color: UIColor) {
        let ring = SKSpriteNode(texture: textures.ring())
        ring.color = color
        ring.colorBlendFactor = 1
        ring.blendMode = .add
        ring.position = orb.position
        ring.zPosition = 280
        ring.setScale(0.4 * spriteScale)
        world.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 3.2 * spriteScale, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
    }

    private func popup(_ text: String, color: UIColor) {
        guard let label = popupPool.first(where: { $0.isHidden }) ?? popupPool.first else { return }
        label.removeAllActions()
        label.text = text
        label.fontColor = color
        label.isHidden = false
        label.alpha = 1
        label.setScale(0.6)
        label.position = CGPoint(x: orb.position.x, y: orb.position.y + 50 * spriteScale)
        let rise = SKAction.moveBy(x: 0, y: 70, duration: 0.6)
        rise.timingMode = .easeOut
        label.run(.sequence([
            .group([rise, .sequence([.scale(to: 1.1, duration: 0.1), .scale(to: 1, duration: 0.1)]),
                    .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.25)])]),
            .run { [weak label] in label?.isHidden = true }
        ]))
    }

    private func banner(_ title: String, subtitle: String?, color: UIColor, small: Bool) {
        let container = SKNode()
        container.zPosition = 450
        container.position = CGPoint(x: 0, y: size.height * (small ? 0.02 : 0.12))
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-HeavyItalic")
        titleLabel.text = title
        titleLabel.fontSize = small ? 26 : 44
        titleLabel.fontColor = color
        titleLabel.verticalAlignmentMode = .center
        container.addChild(titleLabel)
        if let subtitle {
            let sub = SKLabelNode(fontNamed: "AvenirNext-Bold")
            sub.text = subtitle
            sub.fontSize = 16
            sub.fontColor = .white
            sub.position = CGPoint(x: 0, y: -34)
            sub.verticalAlignmentMode = .center
            container.addChild(sub)
        }
        cam.addChild(container)
        container.setScale(0.5)
        container.alpha = 0
        let appear = SKAction.group([.fadeIn(withDuration: 0.15), .scale(to: 1, duration: 0.2)])
        appear.timingMode = .easeOut
        container.run(.sequence([appear, .wait(forDuration: small ? 0.5 : 1.1),
                                 .group([.fadeOut(withDuration: 0.3), .moveBy(x: 0, y: 30, duration: 0.3)]),
                                 .removeFromParent()]))
    }

    private func screenFlash(_ color: UIColor, alpha: CGFloat) {
        let target = style.reducedMotion ? alpha * 0.5 : alpha
        flash.removeAllActions()
        flash.color = color
        flash.alpha = target
        flash.run(.fadeOut(withDuration: 0.35))
    }

    private func shake(intensity: CGFloat) {
        guard !style.reducedMotion else { return }
        cam.removeAction(forKey: "shake")
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        var steps: [SKAction] = []
        var amount = intensity
        for _ in 0..<6 {
            steps.append(.move(to: CGPoint(x: center.x + .random(in: -amount...amount), y: center.y + .random(in: -amount...amount)),
                               duration: 0.03))
            amount *= 0.7
        }
        steps.append(.move(to: center, duration: 0.03))
        cam.run(.sequence(steps), withKey: "shake")
    }

    private func crash() {
        burst(at: orb.position, color: displayedColor.uiColor, count: 60)
        burst(at: orb.position, color: .white, count: 24)
        shockwave(color: displayedColor.uiColor)
        shake(intensity: 16)
        screenFlash(UIColor(hex: 0xFF3355), alpha: 0.45)
        trail?.particleBirthRate = 0
        orb.run(.group([.scale(to: spriteScale * 2.2, duration: 0.18), .fadeOut(withDuration: 0.18)]))
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            switch style.controlScheme {
            case .tap:
                // Screen-space halves: the camera may be mid-shake, so use the view location.
                let x = touch.location(in: view).x
                let width = view?.bounds.width ?? size.width
                controller?.requestMove(x < width / 2 ? -1 : 1)
            case .swipe:
                swipeStarts[ObjectIdentifier(touch)] = point
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard style.controlScheme == .swipe else { return }
        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard let start = swipeStarts[key] else { continue }
            let point = touch.location(in: self)
            let dx = point.x - start.x
            let dy = point.y - start.y
            if abs(dx) > 24 && abs(dx) > abs(dy) {
                controller?.requestMove(dx < 0 ? -1 : 1)
                // One move per swipe; restart tracking so a long drag can chain lanes deliberately.
                swipeStarts[key] = point
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { swipeStarts[ObjectIdentifier($0)] = nil }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { swipeStarts[ObjectIdentifier($0)] = nil }
    }
}

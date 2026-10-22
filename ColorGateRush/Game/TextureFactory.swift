import SpriteKit
import UIKit

/// Renders every in-game sprite procedurally with Core Graphics and caches it as a texture.
/// No bundled image assets are needed, and sprites stay crisp at any device scale.
final class TextureFactory {
    /// Design width of one lane; sprites are authored at this size and scaled to the device.
    static let laneDesignWidth: CGFloat = 120
    static let gateSize = CGSize(width: 108, height: 78)
    static let hazardSize = CGSize(width: 108, height: 64)
    static let shardSize = CGSize(width: 44, height: 44)
    static let shieldSize = CGSize(width: 58, height: 58)
    static let prismSize = CGSize(width: 356, height: 56)
    static let orbSize = CGSize(width: 76, height: 76)

    let colorAssist: Bool
    private var cache: [String: SKTexture] = [:]

    init(colorAssist: Bool) {
        self.colorAssist = colorAssist
    }

    private func cached(_ key: String, size: CGSize, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let texture = cache[key] { return texture }
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            draw(ctx.cgContext, size)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        cache[key] = texture
        return texture
    }

    // MARK: Gates & obstacles

    func gate(_ color: GateColor) -> SKTexture {
        cached("gate.\(color.rawValue)", size: Self.gateSize) { [colorAssist] cg, size in
            let ui = color.uiColor
            let frame = CGRect(origin: .zero, size: size).insetBy(dx: 9, dy: 9)
            let path = UIBezierPath(roundedRect: frame, cornerRadius: 14)
            cg.setFillColor(ui.withAlphaComponent(0.22).cgColor)
            cg.addPath(path.cgPath)
            cg.fillPath()

            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 9, color: ui.cgColor)
            cg.setStrokeColor(ui.cgColor)
            cg.setLineWidth(6)
            cg.addPath(path.cgPath)
            cg.strokePath()
            cg.restoreGState()

            // Bright inner highlight line.
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.55).cgColor)
            cg.setLineWidth(1.5)
            cg.addPath(UIBezierPath(roundedRect: frame.insetBy(dx: 4, dy: 4), cornerRadius: 10).cgPath)
            cg.strokePath()

            let symbolSide: CGFloat = colorAssist ? 34 : 26
            let symbolY = colorAssist ? frame.midY - symbolSide / 2 - 7 : frame.midY - symbolSide / 2
            let symbolRect = CGRect(x: frame.midX - symbolSide / 2, y: symbolY, width: symbolSide, height: symbolSide)
            Self.drawSymbol(color.symbol, in: symbolRect, fill: ui, stroke: .white, context: cg)

            if colorAssist {
                Self.drawText(color.displayName.uppercased(), size: 11, color: .white,
                              center: CGPoint(x: frame.midX, y: frame.maxY - 11), context: cg)
            }
        }
    }

    func hazard() -> SKTexture {
        cached("hazard", size: Self.hazardSize) { cg, size in
            let frame = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
            let path = UIBezierPath(roundedRect: frame, cornerRadius: 8)
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 8, color: UIColor.black.cgColor)
            cg.setFillColor(UIColor(hex: 0x1B1B24).cgColor)
            cg.addPath(path.cgPath)
            cg.fillPath()
            cg.restoreGState()

            // Diagonal warning stripes, clipped to the block.
            cg.saveGState()
            cg.addPath(path.cgPath)
            cg.clip()
            cg.setFillColor(UIColor(hex: 0xF2F2F7, alpha: 0.9).cgColor)
            var x = frame.minX - frame.height
            while x < frame.maxX {
                let stripe = CGMutablePath()
                stripe.move(to: CGPoint(x: x, y: frame.maxY))
                stripe.addLine(to: CGPoint(x: x + 12, y: frame.maxY))
                stripe.addLine(to: CGPoint(x: x + 12 + frame.height, y: frame.minY))
                stripe.addLine(to: CGPoint(x: x + frame.height, y: frame.minY))
                stripe.closeSubpath()
                cg.addPath(stripe)
                x += 26
            }
            cg.fillPath()
            cg.restoreGState()

            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineWidth(3)
            cg.addPath(path.cgPath)
            cg.strokePath()

            // Central X marker so barriers read as "no entry" without relying on color.
            let mark = CGRect(x: frame.midX - 13, y: frame.midY - 13, width: 26, height: 26)
            cg.setFillColor(UIColor(hex: 0x1B1B24).cgColor)
            cg.fillEllipse(in: mark.insetBy(dx: -5, dy: -5))
            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineWidth(4.5)
            cg.setLineCap(.round)
            cg.move(to: CGPoint(x: mark.minX + 4, y: mark.minY + 4))
            cg.addLine(to: CGPoint(x: mark.maxX - 4, y: mark.maxY - 4))
            cg.move(to: CGPoint(x: mark.maxX - 4, y: mark.minY + 4))
            cg.addLine(to: CGPoint(x: mark.minX + 4, y: mark.maxY - 4))
            cg.strokePath()
        }
    }

    func shard() -> SKTexture {
        cached("shard", size: Self.shardSize) { cg, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 9, dy: 6)
            let path = SymbolPath.path(.diamond, in: rect)
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 7, color: UIColor(hex: 0x9FF6FF).cgColor)
            cg.setFillColor(UIColor(hex: 0xE9FDFF).cgColor)
            cg.addPath(path)
            cg.fillPath()
            cg.restoreGState()
            // Facet line.
            cg.setStrokeColor(UIColor(hex: 0x58D6F0).cgColor)
            cg.setLineWidth(1.5)
            cg.move(to: CGPoint(x: rect.minX, y: rect.midY))
            cg.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            cg.move(to: CGPoint(x: rect.midX, y: rect.minY))
            cg.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            cg.strokePath()
        }
    }

    func shield() -> SKTexture {
        cached("shield", size: Self.shieldSize) { cg, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 7, dy: 7)
            let hex = Self.hexagon(in: rect)
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 8, color: UIColor.white.cgColor)
            cg.setFillColor(UIColor.white.withAlphaComponent(0.16).cgColor)
            cg.addPath(hex)
            cg.fillPath()
            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineWidth(3.5)
            cg.addPath(hex)
            cg.strokePath()
            cg.restoreGState()
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .black)
            if let glyph = UIImage(systemName: "shield.fill", withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let g = glyph.size
                glyph.draw(in: CGRect(x: rect.midX - g.width / 2, y: rect.midY - g.height / 2, width: g.width, height: g.height))
            }
        }
    }

    func prismBand(_ color: GateColor) -> SKTexture {
        cached("prism.\(color.rawValue)", size: Self.prismSize) { cg, size in
            let ui = color.uiColor
            let band = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 12)
            let path = UIBezierPath(roundedRect: band, cornerRadius: band.height / 2)
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 12, color: ui.cgColor)
            cg.setFillColor(ui.withAlphaComponent(0.55).cgColor)
            cg.addPath(path.cgPath)
            cg.fillPath()
            cg.restoreGState()

            // Prismatic rim: thin rainbow line along the top edge.
            cg.saveGState()
            cg.addPath(path.cgPath)
            cg.clip()
            let colors = GateColor.allCases.map { $0.uiColor.cgColor } as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil) {
                cg.drawLinearGradient(gradient, start: CGPoint(x: band.minX, y: 0), end: CGPoint(x: band.maxX, y: 0), options: [])
            }
            cg.setFillColor(ui.withAlphaComponent(0.85).cgColor)
            cg.fill(band.insetBy(dx: 0, dy: 4).offsetBy(dx: 0, dy: 3))
            cg.restoreGState()

            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            cg.setLineWidth(2)
            cg.addPath(path.cgPath)
            cg.strokePath()

            let side: CGFloat = 20
            for lane in 0..<3 {
                let cx = band.minX + band.width * (CGFloat(lane) + 0.5) / 3
                let rect = CGRect(x: cx - side / 2, y: band.midY - side / 2 + 1, width: side, height: side)
                Self.drawSymbol(color.symbol, in: rect, fill: .white, stroke: ui.darker(), context: cg)
            }
        }
    }

    // MARK: Orb

    func orb(skin: String) -> SKTexture {
        cached("orb.\(skin)", size: Self.orbSize) { cg, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r: CGFloat = 22
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 12, color: UIColor.white.cgColor)
            cg.setFillColor(UIColor.white.cgColor)
            cg.setStrokeColor(UIColor.white.cgColor)
            switch skin {
            case "skin.pulse":
                cg.fillEllipse(in: CGRect(x: center.x - r * 0.8, y: center.y - r * 0.8, width: r * 1.6, height: r * 1.6))
                cg.setLineWidth(3.5)
                cg.strokeEllipse(in: CGRect(x: center.x - r - 5, y: center.y - r - 5, width: (r + 5) * 2, height: (r + 5) * 2))
            case "skin.hex":
                cg.addPath(Self.hexagon(in: CGRect(x: center.x - r - 2, y: center.y - r - 2, width: (r + 2) * 2, height: (r + 2) * 2)))
                cg.fillPath()
            case "skin.comet":
                let path = CGMutablePath()
                path.addArc(center: CGPoint(x: center.x, y: center.y - 4), radius: r * 0.85, startAngle: 0, endAngle: .pi, clockwise: true)
                path.addLine(to: CGPoint(x: center.x, y: center.y + r + 8))
                path.closeSubpath()
                cg.addPath(path)
                cg.fillPath()
            case "skin.star":
                cg.addPath(SymbolPath.path(.star, in: CGRect(x: center.x - r - 6, y: center.y - r - 6, width: (r + 6) * 2, height: (r + 6) * 2)))
                cg.fillPath()
            case "skin.halo":
                cg.fillEllipse(in: CGRect(x: center.x - r * 0.7, y: center.y - r * 0.7, width: r * 1.4, height: r * 1.4))
                cg.setLineWidth(2.5)
                cg.strokeEllipse(in: CGRect(x: center.x - r - 6, y: center.y - r * 0.55, width: (r + 6) * 2, height: r * 1.1))
                cg.strokeEllipse(in: CGRect(x: center.x - r * 0.55, y: center.y - r - 6, width: r * 1.1, height: (r + 6) * 2))
            case "skin.nova":
                cg.fillEllipse(in: CGRect(x: center.x - r * 0.75, y: center.y - r * 0.75, width: r * 1.5, height: r * 1.5))
                cg.setLineWidth(3)
                cg.setLineCap(.round)
                for i in 0..<8 {
                    let angle = CGFloat(i) * .pi / 4
                    cg.move(to: CGPoint(x: center.x + cos(angle) * r * 0.95, y: center.y + sin(angle) * r * 0.95))
                    cg.addLine(to: CGPoint(x: center.x + cos(angle) * (r + 9), y: center.y + sin(angle) * (r + 9)))
                }
                cg.strokePath()
            case "skin.gem":
                let gem = SymbolPath.path(.diamond, in: CGRect(x: center.x - r, y: center.y - r - 6, width: r * 2, height: (r + 6) * 2))
                cg.addPath(gem)
                cg.fillPath()
            default:
                cg.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            }
            cg.restoreGState()
            // Soft specular highlight gives the orb some volume even when tinted.
            cg.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
            cg.fillEllipse(in: CGRect(x: center.x - r * 0.45, y: center.y - r * 0.6, width: r * 0.5, height: r * 0.32))
        }
    }

    /// White symbol with a dark outline, drawn on top of the tinted orb.
    func orbSymbol(_ symbol: GateSymbol) -> SKTexture {
        cached("orbsym.\(symbol.rawValue)", size: CGSize(width: 30, height: 30)) { cg, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 5, dy: 5)
            Self.drawSymbol(symbol, in: rect, fill: .white, stroke: UIColor(white: 0, alpha: 0.55), context: cg)
        }
    }

    func shieldBubble() -> SKTexture {
        cached("bubble", size: CGSize(width: 110, height: 110)) { cg, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 10, dy: 10)
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 10, color: UIColor.white.cgColor)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            cg.setLineWidth(3)
            cg.addPath(Self.hexagon(in: rect))
            cg.strokePath()
            cg.restoreGState()
            cg.setFillColor(UIColor.white.withAlphaComponent(0.08).cgColor)
            cg.addPath(Self.hexagon(in: rect))
            cg.fillPath()
        }
    }

    // MARK: Effects

    func particle(square: Bool = false) -> SKTexture {
        cached(square ? "particle.square" : "particle", size: CGSize(width: 18, height: 18)) { cg, size in
            if square {
                cg.setFillColor(UIColor.white.cgColor)
                cg.fill(CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4))
                return
            }
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                cg.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: size.width / 2, options: [])
            }
        }
    }

    func ring() -> SKTexture {
        cached("ring", size: CGSize(width: 120, height: 120)) { cg, size in
            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineWidth(5)
            cg.strokeEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 6))
        }
    }

    func streak() -> SKTexture {
        cached("streak", size: CGSize(width: 4, height: 64)) { cg, size in
            let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
    }

    func dash() -> SKTexture {
        cached("dash", size: CGSize(width: 8, height: 40)) { cg, size in
            cg.setFillColor(UIColor.white.cgColor)
            cg.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4).cgPath)
            cg.fillPath()
        }
    }

    /// Full-screen sky gradient with a glow on the horizon.
    func sky(size: CGSize, theme: VisualTheme, horizonFromTop: CGFloat) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let colors = [theme.skyTop.cgColor, theme.skyBottom.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            let glow = [theme.glow.withAlphaComponent(0.55).cgColor, theme.glow.withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glow, locations: [0, 1]) {
                let c = CGPoint(x: size.width / 2, y: horizonFromTop)
                cg.saveGState()
                cg.translateBy(x: c.x, y: c.y)
                cg.scaleBy(x: 1.6, y: 0.55)
                cg.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero,
                                      endRadius: size.width * 0.6, options: [])
                cg.restoreGState()
            }
        }
        return SKTexture(image: image)
    }

    /// The track floor in perspective. `points` are the four corners in top-left image coordinates:
    /// bottom-left, bottom-right, top-right, top-left. `lanes` are divider lines (bottom, top) pairs.
    func track(size: CGSize, theme: VisualTheme, corners: [CGPoint], dividers: [(CGPoint, CGPoint)]) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let floor = CGMutablePath()
            floor.addLines(between: corners)
            floor.closeSubpath()
            cg.saveGState()
            cg.addPath(floor)
            cg.clip()
            let colors = [theme.trackFar.cgColor, theme.track.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: corners[2].y), end: CGPoint(x: 0, y: corners[0].y), options: [])
            }
            cg.restoreGState()

            cg.setLineCap(.round)
            cg.setStrokeColor(theme.lane.cgColor)
            cg.setLineWidth(2)
            for (bottom, top) in dividers {
                cg.move(to: bottom)
                cg.addLine(to: top)
            }
            cg.strokePath()

            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 14, color: theme.edge.cgColor)
            cg.setStrokeColor(theme.edge.cgColor)
            cg.setLineWidth(4)
            cg.move(to: corners[0])
            cg.addLine(to: corners[3])
            cg.move(to: corners[1])
            cg.addLine(to: corners[2])
            cg.strokePath()
            cg.restoreGState()
        }
        return SKTexture(image: image)
    }

    // MARK: Helpers

    static func drawSymbol(_ symbol: GateSymbol, in rect: CGRect, fill: UIColor, stroke: UIColor, context cg: CGContext) {
        let path = SymbolPath.path(symbol, in: rect)
        cg.saveGState()
        cg.setFillColor(fill.cgColor)
        cg.setStrokeColor(stroke.cgColor)
        cg.setLineWidth(2)
        cg.setLineJoin(.round)
        cg.addPath(path)
        cg.drawPath(using: .fillStroke)
        cg.restoreGState()
    }

    static func drawText(_ text: String, size: CGFloat, color: UIColor, center: CGPoint, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: .heavy),
            .foregroundColor: color,
            .kern: 1.2
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let bounds = string.size()
        string.draw(at: CGPoint(x: center.x - bounds.width / 2, y: center.y - bounds.height / 2))
    }

    static func hexagon(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let p = CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

extension UIColor {
    func darker(by amount: CGFloat = 0.45) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return UIColor(hue: h, saturation: s, brightness: max(0, b * (1 - amount)), alpha: a)
    }
}

import SwiftUI

enum UIPalette {
    static let panel = Color(red: 0.08, green: 0.07, blue: 0.19).opacity(0.88)
    static let panelStroke = Color.white.opacity(0.14)
    static let secondaryText = Color.white.opacity(0.7)
    static let shard = Color(red: 0.62, green: 0.96, blue: 1.0)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.3)

    static var brandGradient: LinearGradient {
        LinearGradient(colors: GateColor.allCases.map(\.color), startPoint: .leading, endPoint: .trailing)
    }
}

/// Primary call-to-action: a glowing capsule that compresses when pressed.
struct NeonButtonStyle: ButtonStyle {
    var colors: [Color] = [GateColor.crimson.color, GateColor.violet.color]
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(prominent ? .title2 : .headline, design: .rounded).weight(.heavy))
            .foregroundStyle(.white)
            .padding(.vertical, prominent ? 18 : 13)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1.5))
            .shadow(color: (colors.first ?? .white).opacity(configuration.isPressed ? 0.2 : 0.55), radius: 16, y: 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Secondary button: translucent glass panel.
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(UIPalette.panel))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(UIPalette.panelStroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(UIPalette.panel))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(UIPalette.panelStroke, lineWidth: 1))
    }
}

struct ShardCounter: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 6) {
            GateSymbolShape(symbol: .diamond)
                .fill(UIPalette.shard)
                .frame(width: 14, height: 18)
                .shadow(color: UIPalette.shard, radius: 4)
            Text("\(amount)")
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.35)))
        .overlay(Capsule().stroke(UIPalette.shard.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) shards")
    }
}

/// Title bar used by the menu sub-screens.
struct ScreenHeader: View {
    let title: String
    var shards: Int?
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .heavy))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(UIPalette.panel))
                    .overlay(Circle().stroke(UIPalette.panelStroke, lineWidth: 1))
            }
            .accessibilityLabel("Back")
            Spacer()
            Text(title)
                .font(.system(.title2, design: .rounded).weight(.heavy))
            Spacer()
            if let shards {
                ShardCounter(amount: shards)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(.white)
    }
}

/// Backdrop for menus. The home screen shows a perspective track with gates sliding toward
/// the viewer; sub-screens use a calm gradient so text and panels stay readable.
struct MenuBackground: View {
    let theme: VisualTheme
    var animated = true
    var showsTrack = true

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.skyTopColor, theme.skyBottomColor], startPoint: .top, endPoint: .bottom)
            if !showsTrack {
                HorizonGlow(theme: theme)
            } else if animated {
                TimelineView(.animation) { timeline in
                    TrackCanvas(theme: theme, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                TrackCanvas(theme: theme, time: 0)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Soft elliptical glow; a radial gradient drawn in a scaled context so it has no hard edges.
private func drawGlow(_ context: GraphicsContext, theme: VisualTheme, center: CGPoint, radius: CGFloat) {
    var glow = context
    glow.translateBy(x: center.x, y: center.y)
    glow.scaleBy(x: 1.5, y: 0.45)
    glow.fill(Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
              with: .radialGradient(Gradient(colors: [theme.glowColor.opacity(0.55), theme.glowColor.opacity(0)]),
                                    center: .zero, startRadius: 0, endRadius: radius))
}

private struct HorizonGlow: View {
    let theme: VisualTheme

    var body: some View {
        Canvas { context, size in
            drawGlow(context, theme: theme, center: CGPoint(x: size.width / 2, y: size.height * 0.3), radius: size.width * 0.8)
        }
    }
}

private struct TrackCanvas: View {
    let theme: VisualTheme
    let time: Double

    var body: some View {
        Canvas { context, size in
            let horizon = CGPoint(x: size.width / 2, y: size.height * 0.42)
            let bottomY = size.height * 1.05
            let halfBottom = size.width * 0.75

            drawGlow(context, theme: theme, center: horizon, radius: size.width * 0.8)

            func point(_ lane: CGFloat, _ depth: CGFloat) -> CGPoint {
                // depth 0 = horizon, 1 = bottom of screen.
                let y = horizon.y + (bottomY - horizon.y) * depth
                let x = horizon.x + lane * halfBottom * depth
                return CGPoint(x: x, y: y)
            }

            for lane in [-1.0, -1.0 / 3, 1.0 / 3, 1.0] {
                var line = Path()
                line.move(to: point(lane, 0.02))
                line.addLine(to: point(lane, 1))
                let edge = abs(lane) == 1
                context.stroke(line, with: .color(edge ? theme.edgeColor : theme.edgeColor.opacity(0.25)),
                               lineWidth: edge ? 3 : 1.5)
            }

            // Gates sliding toward the viewer.
            let colors = GateColor.allCases
            for i in 0..<6 {
                let phase = (time * 0.18 + Double(i) / 6).truncatingRemainder(dividingBy: 1)
                let depth = CGFloat(phase * phase)
                guard depth > 0.03 else { continue }
                let laneIndex = (i * 2 + Int(time * 0.18 + Double(i) / 6)) % 3
                let laneCenter = CGFloat(laneIndex - 1) * 2 / 3
                let center = point(laneCenter, depth)
                let width = halfBottom * 2 / 3 * depth * 0.8
                let rect = CGRect(x: center.x - width / 2, y: center.y - width * 0.35, width: width, height: width * 0.7)
                let color = colors[(i + Int(time * 0.18 + Double(i) / 6)) % colors.count]
                let alpha = min(1, depth * 3) * (1 - max(0, depth - 0.8) * 5)
                context.stroke(Path(roundedRect: rect, cornerRadius: width * 0.12),
                               with: .color(color.color.opacity(alpha)), lineWidth: max(1, 6 * depth))
                let symbolSide = width * 0.28
                let symbolRect = CGRect(x: center.x - symbolSide / 2, y: center.y - symbolSide / 2, width: symbolSide, height: symbolSide)
                context.fill(GateSymbolShape(symbol: color.symbol).path(in: symbolRect), with: .color(color.color.opacity(alpha)))
            }
        }
    }
}

extension View {
    /// Standard full-screen menu container.
    func menuScreen(theme: VisualTheme, animated: Bool = true, showsTrack: Bool = false) -> some View {
        self
            .padding(.horizontal, 20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MenuBackground(theme: theme, animated: animated, showsTrack: showsTrack))
    }
}

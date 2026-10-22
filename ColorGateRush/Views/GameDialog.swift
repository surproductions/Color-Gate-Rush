import SwiftUI

/// Content for an in-game confirmation dialog. Replaces the system action sheet so every
/// prompt matches the game's neon look.
struct GameDialogContent {
    enum Tone {
        /// Positive action (unlock, play): brand gradient.
        case primary
        /// Something is lost (quit, reset): crimson gradient.
        case destructive

        var colors: [Color] {
            switch self {
            case .primary: return [GateColor.azure.color, GateColor.violet.color]
            case .destructive: return [GateColor.crimson.color, Color(red: 0.75, green: 0.1, blue: 0.3)]
            }
        }
    }

    var icon: String
    var title: String
    var message: String?
    var confirmTitle: String
    var confirmIcon: String
    var confirmIdentifier: String
    var cancelTitle = "Cancel"
    var tone: Tone = .primary
}

private struct GameDialogModifier<Accessory: View>: ViewModifier {
    @Binding var isPresented: Bool
    let content: GameDialogContent
    let accessory: Accessory
    let onConfirm: () -> Void
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    func body(content base: Content) -> some View {
        base.overlay {
            ZStack {
                if isPresented {
                    Color.black.opacity(0.62)
                        .ignoresSafeArea()
                        .onTapGesture { isPresented = false }
                        .accessibilityHidden(true)
                        .transition(.opacity)
                    card
                        .transition(systemReduceMotion
                                    ? .opacity
                                    : .scale(scale: 0.88).combined(with: .opacity).combined(with: .offset(y: 30)))
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: isPresented)
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: content.tone.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .shadow(color: (content.tone.colors.first ?? .white).opacity(0.6), radius: 16)
                Image(systemName: content.icon)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(content.title)
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                if let message = content.message {
                    Text(message)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(UIPalette.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            accessory

            VStack(spacing: 10) {
                Button {
                    isPresented = false
                    onConfirm()
                } label: {
                    Label(content.confirmTitle, systemImage: content.confirmIcon)
                }
                .buttonStyle(NeonButtonStyle(colors: content.tone.colors, prominent: false))
                .accessibilityIdentifier(content.confirmIdentifier)

                Button { isPresented = false } label: {
                    Text(content.cancelTitle)
                }
                .buttonStyle(GlassButtonStyle())
                .accessibilityIdentifier("dialogCancelButton")
            }
            .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.07, green: 0.06, blue: 0.17))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(LinearGradient(colors: content.tone.colors.map { $0.opacity(0.8) },
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

extension View {
    /// Presents a styled confirmation dialog over this view.
    func gameDialog<Accessory: View>(isPresented: Binding<Bool>,
                                     _ content: GameDialogContent,
                                     onConfirm: @escaping () -> Void,
                                     @ViewBuilder accessory: () -> Accessory) -> some View {
        modifier(GameDialogModifier(isPresented: isPresented, content: content, accessory: accessory(), onConfirm: onConfirm))
    }

    func gameDialog(isPresented: Binding<Bool>,
                    _ content: GameDialogContent,
                    onConfirm: @escaping () -> Void) -> some View {
        gameDialog(isPresented: isPresented, content, onConfirm: onConfirm) { EmptyView() }
    }
}

/// Shard price pill used in purchase dialogs: "◆ 60 → 347 left".
struct ShardPriceRow: View {
    let cost: Int
    let balance: Int

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                GateSymbolShape(symbol: .diamond)
                    .fill(UIPalette.shard)
                    .frame(width: 13, height: 17)
                    .shadow(color: UIPalette.shard, radius: 4)
                Text("\(cost)")
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .monospacedDigit()
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(UIPalette.secondaryText)
            Text("\(max(0, balance - cost)) left")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(UIPalette.secondaryText)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.black.opacity(0.35)))
        .overlay(Capsule().stroke(UIPalette.shard.opacity(0.45), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Costs \(cost) shards. \(max(0, balance - cost)) shards left afterwards.")
    }
}

/// Large segmented chooser for the control scheme, shared by Settings and the pause menu.
struct ControlSchemePicker: View {
    @Binding var selection: ControlScheme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ControlScheme.allCases, id: \.self) { scheme in
                let selected = scheme == selection
                Button {
                    selection = scheme
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: Self.icon(for: scheme))
                            .font(.system(size: 20, weight: .bold))
                        Text(scheme.displayName)
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(selected ? .white : .white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selected
                                  ? AnyShapeStyle(LinearGradient(colors: [GateColor.azure.color.opacity(0.55),
                                                                         GateColor.violet.color.opacity(0.55)],
                                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                                  : AnyShapeStyle(Color.white.opacity(0.06)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selected ? Color.white.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(scheme.displayName)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("controls-\(scheme.rawValue)")
            }
        }
        .animation(.easeOut(duration: 0.15), value: selection)
    }

    static func icon(for scheme: ControlScheme) -> String {
        switch scheme {
        case .both: return "hand.tap.fill"
        case .tap: return "rectangle.split.2x1.fill"
        case .swipe: return "hand.draw.fill"
        }
    }
}

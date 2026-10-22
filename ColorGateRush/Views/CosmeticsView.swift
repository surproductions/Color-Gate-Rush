import SwiftUI

struct CosmeticsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var category: CosmeticCategory = .skin
    @State private var pendingPurchase: CosmeticItem?
    @State private var message: String?

    var body: some View {
        VStack(spacing: 16) {
            ScreenHeader(title: "Style", shards: model.profile.shards) { model.navigate(.home) }
                .padding(.top, 8)

            Picker("Category", selection: $category) {
                ForEach(CosmeticCategory.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            CosmeticPreview(category: category, profile: model.profile)
                .frame(height: 120)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(CosmeticCatalog.items(in: category)) { item in
                        CosmeticCard(item: item,
                                     owned: model.profile.unlockedItems.contains(item.id),
                                     equipped: model.profile.selected(item.category) == item.id,
                                     affordable: model.profile.shards >= item.cost) {
                            select(item)
                        }
                    }
                }
                .padding(.bottom, 24)
            }

            if let message {
                Text(message)
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(UIPalette.secondaryText)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .menuScreen(theme: model.theme, animated: false)
        .animation(.easeInOut(duration: 0.2), value: message)
        .confirmationDialog(pendingPurchase.map { "Unlock \($0.name)?" } ?? "",
                            isPresented: Binding(get: { pendingPurchase != nil }, set: { if !$0 { pendingPurchase = nil } }),
                            titleVisibility: .visible) {
            if let item = pendingPurchase {
                Button("Unlock for \(item.cost) shards") {
                    let result = model.purchase(item)
                    message = Self.describe(result, item: item)
                    pendingPurchase = nil
                }
                Button("Cancel", role: .cancel) { pendingPurchase = nil }
            }
        }
    }

    private func select(_ item: CosmeticItem) {
        if model.profile.unlockedItems.contains(item.id) {
            model.equip(item)
            message = "\(item.name) equipped"
        } else if model.profile.shards >= item.cost {
            pendingPurchase = item
        } else {
            model.haptics.warning()
            message = "You need \(item.cost - model.profile.shards) more shards. Earn them by playing!"
        }
    }

    private static func describe(_ result: PurchaseResult, item: CosmeticItem) -> String {
        switch result {
        case .purchased: return "\(item.name) unlocked and equipped!"
        case .alreadyOwned: return "You already own \(item.name)."
        case .insufficientFunds(let missing): return "You need \(missing) more shards."
        case .unknownItem: return "That item is unavailable."
        }
    }
}

private struct CosmeticCard: View {
    let item: CosmeticItem
    let owned: Bool
    let equipped: Bool
    let affordable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                CosmeticIcon(item: item)
                    .frame(height: 64)
                    .opacity(owned ? 1 : 0.55)
                Text(item.name)
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(item.detail)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(UIPalette.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 30)
                status
            }
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(UIPalette.panel))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(equipped ? UIPalette.shard : UIPalette.panelStroke, lineWidth: equipped ? 2.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name). \(item.detail)")
        .accessibilityValue(equipped ? "Equipped" : owned ? "Owned" : "Locked, costs \(item.cost) shards")
        .accessibilityHint(owned ? "Double tap to equip" : "Double tap to unlock")
    }

    @ViewBuilder
    private var status: some View {
        if equipped {
            Label("Equipped", systemImage: "checkmark.circle.fill")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(UIPalette.shard)
        } else if owned {
            Text("Equip")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
        } else {
            HStack(spacing: 4) {
                Image(systemName: affordable ? "lock.open.fill" : "lock.fill")
                Text("\(item.cost)")
                    .monospacedDigit()
            }
            .font(.system(.caption, design: .rounded).weight(.heavy))
            .foregroundStyle(affordable ? UIPalette.shard : .white.opacity(0.5))
        }
    }
}

/// Lightweight SwiftUI rendition of a cosmetic for menus.
struct CosmeticIcon: View {
    let item: CosmeticItem

    var body: some View {
        switch item.category {
        case .skin:
            OrbGlyph(skinID: item.id, color: GateColor.azure.color)
        case .trail:
            TrailGlyph(trailID: item.id)
        case .theme:
            let theme = VisualTheme.theme(for: item.id)
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [theme.skyTopColor, theme.skyBottomColor], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Path { p in
                        p.move(to: CGPoint(x: 20, y: 64)); p.addLine(to: CGPoint(x: 52, y: 22))
                        p.move(to: CGPoint(x: 100, y: 64)); p.addLine(to: CGPoint(x: 68, y: 22))
                    }
                    .stroke(theme.edgeColor, lineWidth: 2.5)
                )
                .frame(width: 120, height: 64)
        }
    }
}

struct OrbGlyph: View {
    let skinID: String
    let color: Color

    var body: some View {
        ZStack {
            switch skinID {
            case "skin.pulse":
                Circle().fill(color).frame(width: 30, height: 30)
                Circle().stroke(color, lineWidth: 3).frame(width: 46, height: 46)
            case "skin.hex":
                HexagonShape().fill(color).frame(width: 44, height: 44)
            case "skin.comet":
                CometShape().fill(color).frame(width: 36, height: 50)
            case "skin.star":
                GateSymbolShape(symbol: .star).fill(color).frame(width: 50, height: 50)
            case "skin.halo":
                Circle().fill(color).frame(width: 28, height: 28)
                Ellipse().stroke(color, lineWidth: 2.5).frame(width: 54, height: 22)
                Ellipse().stroke(color, lineWidth: 2.5).frame(width: 22, height: 54)
            case "skin.nova":
                Circle().fill(color).frame(width: 30, height: 30)
                ForEach(0..<8, id: \.self) { i in
                    Capsule().fill(color).frame(width: 3, height: 10)
                        .offset(y: -22)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
            case "skin.gem":
                GateSymbolShape(symbol: .diamond).fill(color).frame(width: 40, height: 54)
            default:
                Circle().fill(color).frame(width: 42, height: 42)
            }
        }
        .shadow(color: color, radius: 8)
    }
}

private struct TrailGlyph: View {
    let trailID: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                let color: Color = trailID == "trail.rainbow" ? GateColor.allCases[i].color : GateColor.lime.color
                Group {
                    switch trailID {
                    case "trail.pixel":
                        Rectangle().fill(color).frame(width: 10, height: 10)
                    case "trail.bubble":
                        Circle().stroke(color, lineWidth: 2).frame(width: CGFloat(8 + i * 3), height: CGFloat(8 + i * 3))
                    case "trail.ribbon":
                        Capsule().fill(color).frame(width: 16, height: 6)
                    default:
                        Circle().fill(color).frame(width: CGFloat(4 + i * 2), height: CGFloat(4 + i * 2))
                    }
                }
                .opacity(0.4 + Double(i) * 0.15)
            }
            Circle().fill(Color.white).frame(width: 20, height: 20)
        }
        .shadow(color: GateColor.lime.color.opacity(0.6), radius: 6)
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path { Path(TextureFactory.hexagon(in: rect)) }
}

private struct CometShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.width / 2
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + r), radius: r, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Large preview of the currently equipped item for the selected category.
private struct CosmeticPreview: View {
    let category: CosmeticCategory
    let profile: PlayerProfile

    var body: some View {
        let id = profile.selected(category)
        VStack(spacing: 8) {
            if let item = CosmeticCatalog.item(id) {
                CosmeticIcon(item: item).scaleEffect(1.3)
                Text("Equipped: \(item.name)")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(UIPalette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

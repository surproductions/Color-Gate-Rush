import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var revealed = false

    var body: some View {
        let reduceMotion = model.profile.settings.reducedMotion
        Group {
            if let run = model.lastRun, let rewards = model.lastRewards {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        if run.isTutorial {
                            tutorialSummary(rewards: rewards)
                        } else {
                            runSummary(run: run, rewards: rewards)
                        }
                    }
                    .padding(.vertical, 24)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 30)
                }
            } else {
                // Defensive fallback: never strand the player on an empty screen.
                VStack(spacing: 16) {
                    Text("No run to show").foregroundStyle(.white)
                    Button("Home") { model.navigate(.home) }.buttonStyle(GlassButtonStyle())
                }
            }
        }
        .menuScreen(theme: model.theme, animated: false)
        .onAppear {
            withAnimation(reduceMotion ? nil : Animation.spring(response: 0.55, dampingFraction: 0.8)) { revealed = true }
        }
    }

    @ViewBuilder
    private func tutorialSummary(rewards: RunRewards) -> some View {
        Text("TUTORIAL COMPLETE")
            .font(.system(size: 30, weight: .black, design: .rounded))
            .italic()
            .foregroundStyle(UIPalette.brandGradient)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                RuleRow(symbol: "arrow.left.arrow.right", text: "Tap the left or right side (or swipe) to switch lanes.")
                RuleRow(symbol: "circle.hexagongrid.fill", text: "Fly through gates matching your orb's color and shape.")
                RuleRow(symbol: "xmark.octagon.fill", text: "Striped barriers and wrong colors end the run.")
                RuleRow(symbol: "sparkles", text: "Prisms recolor your orb. Shields save you once.")
            }
        }
        achievementsSection(rewards)
        Button { model.startGame() } label: { Label("START RUSHING", systemImage: "bolt.fill") }
            .buttonStyle(NeonButtonStyle())
            .accessibilityIdentifier("startRushingButton")
        Button { model.navigate(.home) } label: { Label("Home", systemImage: "house.fill") }
            .buttonStyle(GlassButtonStyle())
    }

    @ViewBuilder
    private func runSummary(run: RunSummary, rewards: RunRewards) -> some View {
        Text(rewards.isNewBest ? "NEW BEST!" : "RUN OVER")
            .font(.system(size: 34, weight: .black, design: .rounded))
            .italic()
            .foregroundStyle(rewards.isNewBest ? AnyShapeStyle(UIPalette.brandGradient) : AnyShapeStyle(Color.white))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("resultsTitle")

        VStack(spacing: 2) {
            Text("\(run.score)")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: GateColor.violet.color.opacity(0.6), radius: 16)
            Text(rewards.isNewBest ? "Previous best \(rewards.previousBest)" : "Best \(model.profile.bestScore)")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(UIPalette.secondaryText)
        }
        .accessibilityElement(children: .combine)

        Panel {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                StatTile(title: "Distance", value: "\(Int(run.distance)) m")
                StatTile(title: "Gates", value: "\(run.gatesPassed)")
                StatTile(title: "Best Combo", value: "\(run.maxCombo)")
                StatTile(title: "Tier", value: run.tierReached.name)
                StatTile(title: "Shards Found", value: "\(run.shardsCollected)")
                StatTile(title: "Time", value: Self.format(seconds: run.duration))
            }
        }

        Panel {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SHARDS EARNED")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .tracking(2)
                        .foregroundStyle(UIPalette.secondaryText)
                    Text("\(rewards.shardsFromRun) from run" + (rewards.shardsFromAchievements > 0
                                                                ? " + \(rewards.shardsFromAchievements) from achievements" : ""))
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(UIPalette.secondaryText)
                }
                Spacer()
                Text("+\(rewards.totalShards)")
                    .font(.system(.title, design: .rounded).weight(.black))
                    .foregroundStyle(UIPalette.shard)
            }
        }
        .accessibilityElement(children: .combine)

        achievementsSection(rewards)
        affordableHint

        Button { model.startGame() } label: { Label("RETRY", systemImage: "arrow.counterclockwise") }
            .buttonStyle(NeonButtonStyle())
            .accessibilityIdentifier("retryButton")
        HStack(spacing: 12) {
            Button { model.navigate(.home) } label: { Label("Home", systemImage: "house.fill") }
                .accessibilityIdentifier("homeButton")
            Button { model.navigate(.cosmetics) } label: { Label("Style", systemImage: "paintpalette.fill") }
        }
        .buttonStyle(GlassButtonStyle())
    }

    @ViewBuilder
    private func achievementsSection(_ rewards: RunRewards) -> some View {
        let unlocked = rewards.newAchievementIDs.compactMap(AchievementCatalog.achievement)
        if !unlocked.isEmpty {
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ACHIEVEMENT UNLOCKED")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .tracking(2)
                        .foregroundStyle(UIPalette.gold)
                    ForEach(unlocked, id: \.id) { achievement in
                        HStack(spacing: 12) {
                            Image(systemName: achievement.icon)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(UIPalette.gold)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title).font(.system(.headline, design: .rounded).weight(.bold))
                                Text(achievement.detail).font(.system(.caption, design: .rounded))
                                    .foregroundStyle(UIPalette.secondaryText)
                            }
                            Spacer()
                            Text("+\(achievement.reward)")
                                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                                .foregroundStyle(UIPalette.shard)
                        }
                        .foregroundStyle(.white)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    /// Nudges the player toward the shop when a new item has become affordable.
    @ViewBuilder
    private var affordableHint: some View {
        let profile = model.profile
        let affordable = CosmeticCatalog.all.filter { !profile.unlockedItems.contains($0.id) && $0.cost <= profile.shards }
        if let item = affordable.max(by: { $0.cost < $1.cost }) {
            Text("You can unlock \(item.name) (\(item.category.displayName)) now!")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(UIPalette.shard)
                .multilineTextAlignment(.center)
        }
    }

    static func format(seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(UIPalette.secondaryText)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct RuleRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(UIPalette.shard)
                .frame(width: 28)
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

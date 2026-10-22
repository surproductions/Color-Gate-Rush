import SwiftUI

/// Lifetime stats, achievements and recent runs.
struct ProgressScreen: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let profile = model.profile
        VStack(spacing: 16) {
            ScreenHeader(title: "Progress", shards: profile.shards) { model.navigate(.home) }
                .padding(.top, 8)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Panel {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            Stat(title: "Best Score", value: "\(profile.bestScore)")
                            Stat(title: "Best Distance", value: "\(Int(profile.bestDistance)) m")
                            Stat(title: "Best Combo", value: "\(profile.bestCombo)")
                            Stat(title: "Highest Tier", value: profile.highestTier.name)
                            Stat(title: "Runs", value: "\(profile.totalRuns)")
                            Stat(title: "Gates Passed", value: "\(profile.totalGates)")
                        }
                    }

                    TierLadder(highest: profile.highestTier)

                    Panel {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("ACHIEVEMENTS")
                                    .font(.system(.caption, design: .rounded).weight(.heavy))
                                    .tracking(2)
                                Spacer()
                                Text("\(profile.achievements.count)/\(AchievementCatalog.all.count)")
                                    .font(.system(.caption, design: .rounded).weight(.heavy))
                                    .monospacedDigit()
                            }
                            .foregroundStyle(UIPalette.secondaryText)
                            ForEach(AchievementCatalog.all, id: \.id) { achievement in
                                AchievementRow(achievement: achievement, unlocked: profile.achievements.contains(achievement.id))
                            }
                        }
                    }

                    if !profile.recentRuns.isEmpty {
                        Panel {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("RECENT RUNS")
                                    .font(.system(.caption, design: .rounded).weight(.heavy))
                                    .tracking(2)
                                    .foregroundStyle(UIPalette.secondaryText)
                                ForEach(Array(profile.recentRuns.enumerated()), id: \.offset) { _, run in
                                    HStack {
                                        Text(run.date, style: .relative)
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(UIPalette.secondaryText)
                                        Spacer()
                                        Text("\(Int(run.distance)) m · \(run.tier.name)")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(UIPalette.secondaryText)
                                        Text("\(run.score)")
                                            .font(.system(.headline, design: .rounded).weight(.heavy))
                                            .monospacedDigit()
                                            .foregroundStyle(.white)
                                            .frame(minWidth: 60, alignment: .trailing)
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .menuScreen(theme: model.theme, animated: false)
    }
}

private struct Stat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(UIPalette.secondaryText)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct TierLadder: View {
    let highest: Tier

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Text("DIFFICULTY TIERS")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(UIPalette.secondaryText)
                ForEach(Tier.allCases, id: \.self) { tier in
                    let reached = tier <= highest
                    HStack(spacing: 10) {
                        HStack(spacing: 3) {
                            ForEach(GateColor.palette(count: tier.colorCount), id: \.self) { color in
                                GateSymbolShape(symbol: color.symbol)
                                    .fill(color.color)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .frame(width: 80, alignment: .leading)
                        Text(tier.name)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Int(tier.startDistance)) m")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(UIPalette.secondaryText)
                        Image(systemName: reached ? "checkmark.seal.fill" : "lock.fill")
                            .foregroundStyle(reached ? UIPalette.shard : .white.opacity(0.35))
                    }
                    .opacity(reached ? 1 : 0.6)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(tier.name), starts at \(Int(tier.startDistance)) metres, \(tier.colorCount) colors, \(reached ? "reached" : "locked")")
                }
            }
        }
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let unlocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: unlocked ? achievement.icon : "lock.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(unlocked ? UIPalette.gold : .white.opacity(0.35))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(unlocked ? 1 : 0.7))
                Text(achievement.detail)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(UIPalette.secondaryText)
            }
            Spacer()
            Text(unlocked ? "Done" : "+\(achievement.reward)")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(unlocked ? UIPalette.gold : UIPalette.shard)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(unlocked ? "Unlocked" : "Locked, rewards \(achievement.reward) shards")
    }
}

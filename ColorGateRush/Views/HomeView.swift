import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var appeared = false
    @State private var pulse = false

    var body: some View {
        let profile = model.profile
        let reduceMotion = profile.settings.reducedMotion
        VStack(spacing: 0) {
            HStack {
                ShardCounter(amount: profile.shards)
                Spacer()
                Button { model.navigate(.settings) } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(UIPalette.panel))
                        .overlay(Circle().stroke(UIPalette.panelStroke, lineWidth: 1))
                }
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("settingsButton")
            }
            .foregroundStyle(.white)
            .padding(.top, 8)

            Spacer(minLength: 20)

            TitleLogo(animate: !reduceMotion)
                .scaleEffect(appeared ? 1 : 0.85)
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 24)

            VStack(spacing: 6) {
                Text("BEST")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .tracking(3)
                    .foregroundStyle(UIPalette.secondaryText)
                Text("\(profile.bestScore)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                if profile.highestTier > .warmUp {
                    Text("Highest tier: \(profile.highestTier.name)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(UIPalette.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Best score \(profile.bestScore)")

            Spacer(minLength: 24)

            Button { model.play() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text(profile.tutorialCompleted ? "PLAY" : "START")
                }
            }
            .buttonStyle(NeonButtonStyle())
            .scaleEffect(pulse ? 1.03 : 1)
            .accessibilityLabel(profile.tutorialCompleted ? "Play" : "Start tutorial")
            .accessibilityIdentifier("playButton")

            HStack(spacing: 12) {
                Button { model.navigate(.cosmetics) } label: {
                    Label("Style", systemImage: "paintpalette.fill")
                }
                .accessibilityIdentifier("cosmeticsButton")
                Button { model.navigate(.progress) } label: {
                    Label("Progress", systemImage: "trophy.fill")
                }
                .accessibilityIdentifier("progressButton")
            }
            .buttonStyle(GlassButtonStyle())
            .padding(.top, 14)

            Text(profile.tutorialCompleted
                 ? "Match your orb's color. Dodge the barriers."
                 : "New here? The quick tutorial starts first.")
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(UIPalette.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .padding(.bottom, 12)
        }
        .menuScreen(theme: model.theme, animated: !reduceMotion, showsTrack: true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// The game's wordmark: each letter block uses a gate color.
struct TitleLogo: View {
    var animate = true
    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 10) {
                ForEach(Array(GateColor.allCases.prefix(4).enumerated()), id: \.offset) { index, color in
                    GateSymbolShape(symbol: color.symbol)
                        .fill(color.color)
                        .frame(width: 22, height: 22)
                        .shadow(color: color.color, radius: 6)
                        .offset(y: shimmer ? -4 : 4)
                        .animation(animate ? .easeInOut(duration: 0.9).repeatForever().delay(Double(index) * 0.15) : nil,
                                   value: shimmer)
                }
            }
            .padding(.bottom, 10)
            Text("COLOR GATE")
                .font(.system(size: 46, weight: .black, design: .rounded))
                .italic()
                .foregroundStyle(.white)
                .shadow(color: GateColor.violet.color.opacity(0.8), radius: 12)
            Text("RUSH")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .italic()
                .foregroundStyle(UIPalette.brandGradient)
                .shadow(color: GateColor.crimson.color.opacity(0.6), radius: 14)
        }
        .minimumScaleFactor(0.6)
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Color Gate Rush")
        .accessibilityAddTraits(.isHeader)
        .onAppear { if animate { shimmer = true } }
    }
}

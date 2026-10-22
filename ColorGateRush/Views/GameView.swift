import SpriteKit
import SwiftUI

/// Hosts one run: the SpriteKit scene plus the SwiftUI HUD, countdown, hints and pause menu.
struct GameView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var controller: GameController
    @State private var confirmRestart = false
    @State private var confirmQuit = false

    init(model: AppModel) {
        let mode = model.gameMode
        _controller = StateObject(wrappedValue: {
            let controller = GameController(mode: mode,
                                            style: model.sceneStyle,
                                            audio: model.audio,
                                            haptics: model.haptics,
                                            seed: model.debug.seed) { [weak model] summary in
                model?.finishRun(summary)
            }
            #if DEBUG
            if model.debug.autopilot { controller.scene.autopilot = Autopilot() }
            controller.scene.autopilotSeconds = model.debug.autopilotSeconds
            controller.scene.showsDebugOverlay = model.debug.overlay
            #endif
            return controller
        }())
    }

    var body: some View {
        ZStack {
            SpriteView(scene: controller.scene,
                       preferredFramesPerSecond: 120,
                       options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .accessibilityLabel("Game area. " + model.profile.settings.controlScheme.instructions)
                .accessibilityAddTraits(.allowsDirectInteraction)

            HUDView(hud: controller.hud, onPause: controller.pause)
                .opacity(controller.isPaused ? 0 : 1)

            if controller.isPaused {
                PauseMenu(onResume: controller.resume,
                          onRestart: { confirmRestart = true },
                          onQuit: { confirmQuit = true })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: controller.isPaused)
        .onChange(of: model.isActive) { active in
            if !active { controller.handleInterruption() }
        }
        .onChange(of: model.profile.settings.controlScheme) { scheme in
            controller.scene.controlScheme = scheme
        }
        .gameDialog(isPresented: $confirmRestart,
                    GameDialogContent(icon: "arrow.counterclockwise", title: "Restart this run?",
                                      message: "Your current score won't be saved.",
                                      confirmTitle: "Restart", confirmIcon: "arrow.counterclockwise",
                                      confirmIdentifier: "confirmRestartButton", cancelTitle: "Keep Playing",
                                      tone: .destructive)) {
            controller.restart()
        }
        .gameDialog(isPresented: $confirmQuit,
                    GameDialogContent(icon: "house.fill", title: "Quit to home?",
                                      message: "Your current score won't be saved.",
                                      confirmTitle: "Quit Run", confirmIcon: "xmark",
                                      confirmIdentifier: "confirmQuitButton", cancelTitle: "Keep Playing",
                                      tone: .destructive)) {
            model.abandonRun()
        }
        .statusBarHidden(true)
    }
}

private struct HUDView: View {
    @ObservedObject var hud: HUDModel
    let onPause: () -> Void

    var body: some View {
        let state = hud.state
        ZStack {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(state.distance) m")
                            .font(.system(.headline, design: .rounded).weight(.heavy))
                            .monospacedDigit()
                        if !state.isTutorial {
                            Text(state.tier.name.uppercased())
                                .font(.system(.caption2, design: .rounded).weight(.heavy))
                                .tracking(1.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.15)))
                        } else {
                            Text("TUTORIAL")
                                .font(.system(.caption2, design: .rounded).weight(.heavy))
                                .tracking(1.5)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)

                    VStack(spacing: 0) {
                        Text("\(state.score)")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .fixedSize(horizontal: true, vertical: false)
                            .shadow(color: .black.opacity(0.5), radius: 4)
                        if state.combo > 1 {
                            Text("x\(state.multiplier)  •  \(state.combo) combo")
                                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                                .foregroundStyle(state.color.color)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .shadow(color: .black.opacity(0.6), radius: 3)
                        }
                    }
                    .layoutPriority(1)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Score \(state.score), combo \(state.combo)")

                    HStack {
                        Spacer()
                        Button(action: onPause) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 20, weight: .black))
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.black.opacity(0.35)))
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        }
                        .accessibilityLabel("Pause")
                        .accessibilityIdentifier("pauseButton")
                    }
                    .frame(maxWidth: .infinity)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.top, 6)

                if let hint = state.hint {
                    Text(hint)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.55)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(state.color.color.opacity(0.7), lineWidth: 1.5))
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .id(hint)
                        .allowsHitTesting(false)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                Spacer()

                HStack(spacing: 8) {
                    GateSymbolShape(symbol: state.color.symbol)
                        .fill(state.color.color)
                        .frame(width: 18, height: 18)
                    Text(state.color.displayName.uppercased())
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .tracking(1.5)
                    if state.hasShield {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 14, weight: .bold))
                            .padding(.leading, 6)
                            .accessibilityLabel("Shield active")
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.4)))
                .padding(.bottom, 10)
                .allowsHitTesting(false)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Your color: \(state.color.displayName)\(state.hasShield ? ", shield active" : "")")
            }
            .animation(.easeInOut(duration: 0.25), value: state.hint)

            if let count = state.countdown {
                Text("\(count)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(.white)
                    .shadow(color: state.color.color, radius: 20)
                    .id(count)
                    .transition(.scale(scale: 1.6).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .accessibilityLabel("Starting in \(count)")
            }
        }
        .animation(.easeOut(duration: 0.2), value: state.countdown)
    }
}

private struct PauseMenu: View {
    @EnvironmentObject private var model: AppModel
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("PAUSED")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, 8)
                Button(action: onResume) { Label("Resume", systemImage: "play.fill") }
                    .buttonStyle(NeonButtonStyle(colors: [GateColor.lime.color, GateColor.azure.color]))
                    .accessibilityIdentifier("resumeButton")
                Button(action: onRestart) { Label("Restart", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(GlassButtonStyle())
                    .accessibilityIdentifier("restartButton")
                Button(action: onQuit) { Label("Home", systemImage: "house.fill") }
                    .buttonStyle(GlassButtonStyle())
                    .accessibilityIdentifier("quitButton")
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONTROLS")
                        .font(.system(.caption2, design: .rounded).weight(.heavy))
                        .tracking(2)
                        .foregroundStyle(UIPalette.secondaryText)
                    ControlSchemePicker(selection: Binding(
                        get: { model.profile.settings.controlScheme },
                        set: { scheme in model.updateSettings { $0.controlScheme = scheme } }))
                }
                .padding(.top, 8)
                HStack(spacing: 12) {
                    QuickToggle(icon: model.profile.settings.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                                label: "Sound", isOn: model.profile.settings.soundEnabled) {
                        model.updateSettings { $0.soundEnabled.toggle() }
                    }
                    QuickToggle(icon: model.profile.settings.musicEnabled ? "music.note" : "music.note.list",
                                label: "Music", isOn: model.profile.settings.musicEnabled) {
                        model.updateSettings { $0.musicEnabled.toggle() }
                    }
                    QuickToggle(icon: "iphone.radiowaves.left.and.right",
                                label: "Haptics", isOn: model.profile.settings.hapticsEnabled) {
                        model.updateSettings { $0.hapticsEnabled.toggle() }
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 380)
        }
    }
}

private struct QuickToggle: View {
    let icon: String
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20, weight: .bold))
                Text(label).font(.system(.caption, design: .rounded).weight(.bold))
            }
            .foregroundStyle(isOn ? .white : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(isOn ? 0.14 : 0.05)))
        }
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

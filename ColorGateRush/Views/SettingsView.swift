import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmReset = false
    @State private var resetDone = false

    var body: some View {
        let settings = model.profile.settings
        VStack(spacing: 16) {
            ScreenHeader(title: "Settings") { model.navigate(.home) }
                .padding(.top, 8)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Panel {
                        VStack(spacing: 14) {
                            sectionTitle("AUDIO")
                            Toggle("Music", isOn: binding(\.musicEnabled))
                            VolumeSlider(label: "Music volume", value: binding(\.musicVolume))
                                .disabled(!settings.musicEnabled)
                            Toggle("Sound effects", isOn: binding(\.soundEnabled))
                            VolumeSlider(label: "Effects volume", value: binding(\.soundVolume))
                                .disabled(!settings.soundEnabled)
                            Toggle("Haptics", isOn: binding(\.hapticsEnabled))
                        }
                    }

                    Panel {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("CONTROLS")
                            Picker("Controls", selection: binding(\.controlScheme)) {
                                ForEach(ControlScheme.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            Text(settings.controlScheme == .tap
                                 ? "Tap the left or right half of the screen to move one lane."
                                 : "Swipe left or right anywhere to move one lane.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(UIPalette.secondaryText)
                        }
                    }

                    Panel {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("ACCESSIBILITY")
                            Toggle("Color assist", isOn: binding(\.colorAssist))
                            Text("Shows larger shapes and color names on every gate.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(UIPalette.secondaryText)
                            HStack(spacing: 10) {
                                ForEach(GateColor.allCases, id: \.self) { color in
                                    VStack(spacing: 3) {
                                        GateSymbolShape(symbol: color.symbol).fill(color.color).frame(width: 18, height: 18)
                                        Text(color.displayName).font(.system(size: 9, weight: .bold, design: .rounded))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("\(color.displayName) is a \(color.symbol.rawValue)")
                                }
                            }
                            Toggle("Reduce motion", isOn: binding(\.reducedMotion))
                            Text("Removes screen shake and speed lines, and calms menu animations.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(UIPalette.secondaryText)
                        }
                    }

                    Panel {
                        VStack(spacing: 12) {
                            sectionTitle("GAME")
                            Button { model.startTutorial() } label: { Label("Replay Tutorial", systemImage: "graduationcap.fill") }
                                .buttonStyle(GlassButtonStyle())
                                .accessibilityIdentifier("replayTutorialButton")
                            Button(role: .destructive) { confirmReset = true } label: {
                                Label("Reset Progress", systemImage: "trash.fill")
                                    .foregroundStyle(GateColor.crimson.color)
                            }
                            .buttonStyle(GlassButtonStyle())
                            if resetDone {
                                Text("Progress reset.")
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .foregroundStyle(UIPalette.secondaryText)
                            }
                        }
                    }

                    Text("Color Gate Rush \(Self.versionString)\nAll progress is stored on this device. No accounts, ads or tracking.")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(UIPalette.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 24)
                }
            }
            .tint(GateColor.azure.color)
            .foregroundStyle(.white)
            .font(.system(.body, design: .rounded).weight(.semibold))
        }
        .menuScreen(theme: model.theme, animated: false)
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset Everything", role: .destructive) {
                model.resetProgress()
                resetDone = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Best scores, shards, unlocks, achievements and tutorial progress will be erased. Settings are kept. This cannot be undone.")
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded).weight(.heavy))
            .tracking(2)
            .foregroundStyle(UIPalette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<GameSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.profile.settings[keyPath: keyPath] },
            set: { newValue in model.updateSettings { $0[keyPath: keyPath] = newValue } }
        )
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct VolumeSlider: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill").font(.caption).opacity(0.6)
            Slider(value: $value, in: 0...1)
                .accessibilityLabel(label)
            Image(systemName: "speaker.wave.3.fill").font(.caption).opacity(0.6)
        }
    }
}

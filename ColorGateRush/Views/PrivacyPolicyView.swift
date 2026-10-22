import SwiftUI

/// In-app copy of the privacy policy. The full text is also published at `PrivacyPolicy.url`.
struct PrivacyPolicyView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            ScreenHeader(title: "Privacy") { model.navigate(.settings) }
                .padding(.top, 8)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Effective October 22, 2026")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(UIPalette.secondaryText)
                    ForEach(PrivacyPolicy.sections, id: \.title) { section in
                        Panel {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title)
                                    .font(.system(.headline, design: .rounded).weight(.heavy))
                                    .accessibilityAddTraits(.isHeader)
                                Text(section.body)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    Link(destination: PrivacyPolicy.url) {
                        Label("View full policy online", systemImage: "safari.fill")
                    }
                    .buttonStyle(GlassButtonStyle())
                    .padding(.bottom, 24)
                }
                .foregroundStyle(.white)
            }
        }
        .menuScreen(theme: model.theme, animated: false)
    }
}

enum PrivacyPolicy {
    static let url = URL(string: "https://github.com/surproductions/Color-Gate-Rush/blob/main/PRIVACY.md")!

    static let sections: [(title: String, body: String)] = [
        ("No data collected",
         "Color Gate Rush does not collect, transmit or share any personal information. There are no accounts, analytics, ads, crash reporters or trackers, and the app makes no network requests."),
        ("Stored on your device",
         "Your best scores, run history, achievements, unlocked cosmetics, shards, settings and tutorial progress are saved only on this device. You can erase them any time with Settings → Reset Progress, or by deleting the app."),
        ("No tracking",
         "The app does not track you across apps or websites and does not use the advertising identifier."),
        ("Children",
         "The game is suitable for all ages and collects no information from anyone, including children."),
        ("Purchases and ads",
         "There are no in-app purchases and no advertisements. Shards are earned only by playing and have no real-world value."),
        ("Contact",
         "Questions about this policy can be submitted at github.com/surproductions/Color-Gate-Rush/issues.")
    ]
}

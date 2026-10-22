import UIKit

/// Thin wrapper over UIKit feedback generators that respects the player's setting.
/// Generators are no-ops on hardware without a Taptic Engine.
@MainActor
final class HapticsManager {
    var isEnabled = true

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    func prepare() {
        guard isEnabled else { return }
        lightGenerator.prepare()
        mediumGenerator.prepare()
        notificationGenerator.prepare()
    }

    func light() {
        guard isEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.7)
    }

    func medium() {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred()
    }

    func heavy() {
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
    }

    func success() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    func warning() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
    }

    func error() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }

    func selection() {
        guard isEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.4)
    }
}

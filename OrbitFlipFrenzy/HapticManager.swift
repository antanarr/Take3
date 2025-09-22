import Foundation
import UIKit

public protocol HapticProviding {
    func playerAction()
    func collision()
    func milestone()
    func nearMiss()
}

public final class HapticManager: HapticProviding {
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    public init() {
        prepare()
    }

    public func prepare() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        notificationGenerator.prepare()
    }

    public func playerAction() {
        lightGenerator.impactOccurred(intensity: 0.3)
    }

    public func collision() {
        notificationGenerator.notificationOccurred(.error)
    }

    public func milestone() {
        mediumGenerator.impactOccurred(intensity: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.mediumGenerator.impactOccurred(intensity: 0.8)
        }
    }

    public func nearMiss() {
        lightGenerator.impactOccurred(intensity: 0.2)
    }
}

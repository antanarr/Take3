import Foundation
import SpriteKit

public enum PowerUpType: String, Codable, CaseIterable {
    case shield
    case slowMo
    case magnet

    public var displayName: String {
        switch self {
        case .shield:
            return "Shield"
        case .slowMo:
            return "Slow-Mo"
        case .magnet:
            return "Magnet"
        }
    }
}

public enum PowerUp: CustomStringConvertible, Codable {
    case shield(duration: TimeInterval)
    case slowMo(factor: CGFloat, duration: TimeInterval)
    case magnet(strength: CGFloat, duration: TimeInterval)

    public var type: PowerUpType {
        switch self {
        case .shield:
            return .shield
        case .slowMo:
            return .slowMo
        case .magnet:
            return .magnet
        }
    }

    public var description: String {
        switch self {
        case let .shield(duration):
            return "shield(\(duration))"
        case let .slowMo(factor, duration):
            return "slowMo(\(factor), \(duration))"
        case let .magnet(strength, duration):
            return "magnet(\(strength), \(duration))"
        }
    }

    public var slowFactor: CGFloat? {
        if case let .slowMo(factor, _) = self { return factor }
        return nil
    }

    public var magnetStrength: CGFloat? {
        if case let .magnet(strength, _) = self { return strength }
        return nil
    }
}

private struct ActivePowerUpEntry {
    let powerUp: PowerUp
    let expiresAt: TimeInterval
    let startedAt: TimeInterval
}

public protocol PowerupManaging: AnyObject {
    func activate(_ powerUp: PowerUp, currentTime: TimeInterval)
    func isActive(_ type: PowerUpType, currentTime: TimeInterval) -> Bool
    func currentPowerUp(of type: PowerUpType) -> PowerUp?
    func timeRemaining(for type: PowerUpType, currentTime: TimeInterval) -> TimeInterval?
    func update(currentTime: TimeInterval)
    func deactivate(_ type: PowerUpType)
    func reset()
    var activeTypes: [PowerUpType] { get }
    func normalizedStrength(for type: PowerUpType, currentTime: TimeInterval) -> CGFloat?
}

public final class PowerupManager: PowerupManaging {
    private var active: [ActivePowerUpEntry] = []

    public init() {}

    public func activate(_ powerUp: PowerUp, currentTime: TimeInterval) {
        let duration: TimeInterval
        switch powerUp {
        case let .shield(durationValue):
            duration = durationValue
        case let .slowMo(_, durationValue):
            duration = durationValue
        case let .magnet(_, durationValue):
            duration = durationValue
        }

        active.removeAll { $0.powerUp.type == powerUp.type }
        let entry = ActivePowerUpEntry(powerUp: powerUp, expiresAt: currentTime + duration, startedAt: currentTime)
        active.append(entry)
    }

    public func isActive(_ type: PowerUpType, currentTime: TimeInterval) -> Bool {
        cleanupExpired(currentTime: currentTime)
        return active.contains { $0.powerUp.type == type }
    }

    public func currentPowerUp(of type: PowerUpType) -> PowerUp? {
        active.first { $0.powerUp.type == type }?.powerUp
    }

    public func timeRemaining(for type: PowerUpType, currentTime: TimeInterval) -> TimeInterval? {
        cleanupExpired(currentTime: currentTime)
        guard let entry = active.first(where: { $0.powerUp.type == type }) else { return nil }
        return max(0, entry.expiresAt - currentTime)
    }

    public func update(currentTime: TimeInterval) {
        cleanupExpired(currentTime: currentTime)
    }

    public func deactivate(_ type: PowerUpType) {
        active.removeAll { $0.powerUp.type == type }
    }

    public func reset() {
        active.removeAll(keepingCapacity: false)
    }

    public var activeTypes: [PowerUpType] {
        active.map { $0.powerUp.type }
    }

    public func normalizedStrength(for type: PowerUpType, currentTime: TimeInterval) -> CGFloat? {
        cleanupExpired(currentTime: currentTime)
        guard let entry = active.first(where: { $0.powerUp.type == type }) else { return nil }
        let duration = max(entry.expiresAt - entry.startedAt, 0.0001)
        let remaining = max(entry.expiresAt - currentTime, 0)
        return CGFloat(remaining / duration)
    }

    private func cleanupExpired(currentTime: TimeInterval) {
        active.removeAll { currentTime >= $0.expiresAt }
    }
}

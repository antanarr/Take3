import Foundation
import SpriteKit

public enum PowerUp: CustomStringConvertible, Codable {
    case shield(duration: TimeInterval)
    case slowMo(factor: CGFloat, duration: TimeInterval)
    case magnet(strength: CGFloat, duration: TimeInterval)

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
}

public enum PowerUpType: String, Codable {
    case shield
    case slowMo
    case magnet
}

private struct ActivePowerup {
    let type: PowerUp
    let expiresAt: TimeInterval
}

public protocol PowerupManaging {
    func activate(_ powerUp: PowerUp, currentTime: TimeInterval)
    func isActive(_ type: PowerUpType, currentTime: TimeInterval) -> Bool
    func currentPowerUp(of type: PowerUpType) -> PowerUp?
    func update(currentTime: TimeInterval)
    var activeTypes: [PowerUpType] { get }
}

public final class PowerupManager: PowerupManaging {
    private var active: [ActivePowerup] = []

    public init() {}

    public func activate(_ powerUp: PowerUp, currentTime: TimeInterval) {
        let duration: TimeInterval
        switch powerUp {
        case let .shield(d):
            duration = d
        case let .slowMo(_, d):
            duration = d
        case let .magnet(_, d):
            duration = d
        }
        let activePowerup = ActivePowerup(type: powerUp, expiresAt: currentTime + duration)
        active.removeAll { $0.type.type == powerUp.type }
        active.append(activePowerup)
    }

    public func isActive(_ type: PowerUpType, currentTime: TimeInterval) -> Bool {
        active.contains { $0.type.type == type && currentTime < $0.expiresAt }
    }

    public func update(currentTime: TimeInterval) {
        active.removeAll { currentTime >= $0.expiresAt }
    }

    public var activeTypes: [PowerUpType] {
        active.map { $0.type.type }
    }

    public func currentPowerUp(of type: PowerUpType) -> PowerUp? {
        active.first { $0.type.type == type }?.type
    }
}

public extension PowerUpType {
    var displayName: String {
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

public extension PowerUp {
    var slowFactor: CGFloat? {
        if case let .slowMo(factor, _) = self { return factor }
        return nil
    }

    var magnetStrength: CGFloat? {
        if case let .magnet(strength, _) = self { return strength }
        return nil
    }
}

import Foundation

public enum AnalyticsEvent: CustomStringConvertible {
    case gameStart(level: Int)
    case gameOver(score: Int, duration: TimeInterval)
    case nearMiss(count: Int)
    case powerupUsed(type: PowerUp)
    case adWatched(placement: String)
    case shareInitiated

    public var description: String {
        switch self {
        case let .gameStart(level):
            return "gameStart(level: \(level))"
        case let .gameOver(score, duration):
            return String(format: "gameOver(score: %d, duration: %.2f)", score, duration)
        case let .nearMiss(count):
            return "nearMiss(count: \(count))"
        case let .powerupUsed(type):
            return "powerupUsed(\(type))"
        case let .adWatched(placement):
            return "adWatched(placement: \(placement))"
        case .shareInitiated:
            return "shareInitiated"
        }
    }
}

public protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

public final class Analytics: AnalyticsTracking {
    public init() {}

    public func track(_ event: AnalyticsEvent) {
        print("Analytics: \(event.description)")
    }
}

import Foundation

public struct DailyStreak: Codable {
    public var streakDays: Int
    public var lastDate: Date
    public var multiplierActiveUntil: Date?

    public init(streakDays: Int = 1, lastDate: Date = Date(), multiplierActiveUntil: Date? = nil) {
        self.streakDays = streakDays
        self.lastDate = lastDate
        self.multiplierActiveUntil = multiplierActiveUntil
    }

    public var reward: Double {
        return 50.0 * pow(1.5, Double(max(streakDays - 1, 0)))
    }

    public var multiplierBonus: Double { 1.1 }

    public var isMultiplierActive: Bool {
        guard let until = multiplierActiveUntil else { return false }
        return Date() <= until
    }
}

public final class GameData {
    public static let shared = GameData()

    private enum Keys {
        static let highScore = "com.orbitflip.highscore"
        static let gems = "com.orbitflip.gems"
        static let streak = "com.orbitflip.streak"
        static let lastStarterPackPrompt = "com.orbitflip.starterpack.prompt"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bootstrapStreakIfNeeded()
    }

    public var highScore: Int {
        get { defaults.integer(forKey: Keys.highScore) }
        set { defaults.set(newValue, forKey: Keys.highScore) }
    }

    public var gems: Int {
        get { defaults.integer(forKey: Keys.gems) }
        set { defaults.set(newValue, forKey: Keys.gems) }
    }

    public var dailyStreak: DailyStreak {
        get {
            guard let data = defaults.data(forKey: Keys.streak),
                  let streak = try? JSONDecoder().decode(DailyStreak.self, from: data) else {
                return DailyStreak(streakDays: 1, lastDate: Date(), multiplierActiveUntil: nil)
            }
            return streak
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.streak)
            }
        }
    }

    public func registerDailyPlay() -> DailyStreak {
        var streak = dailyStreak
        let calendar = Calendar.current
        if calendar.isDateInToday(streak.lastDate) {
            return streak
        }
        if calendar.isDateInYesterday(streak.lastDate) {
            streak.streakDays += 1
        } else if !calendar.isDateInToday(streak.lastDate) {
            streak.streakDays = 1
        }
        streak.lastDate = Date()
        streak.multiplierActiveUntil = Calendar.current.date(byAdding: .hour, value: 24, to: Date())
        dailyStreak = streak
        gems += Int(streak.reward)
        return streak
    }

    public func consumeMultiplierBonus() {
        var streak = dailyStreak
        streak.multiplierActiveUntil = nil
        dailyStreak = streak
    }

    private func bootstrapStreakIfNeeded() {
        if defaults.data(forKey: Keys.streak) == nil {
            dailyStreak = DailyStreak(streakDays: 1, lastDate: Date())
        }
    }

    public func shouldOfferStarterPack() -> Bool {
        guard let lastPrompt = defaults.object(forKey: Keys.lastStarterPackPrompt) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastPrompt) > 24 * 60 * 60
    }

    public func markStarterPackPrompted() {
        defaults.set(Date(), forKey: Keys.lastStarterPackPrompt)
    }
}

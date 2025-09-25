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

public struct OnboardingState: Codable {
    public var tapComplete: Bool
    public var doubleFlipComplete: Bool
    public var orbitSwapComplete: Bool
    public var hasSeenCurrency: Bool
    public var hasSeenPremiumStore: Bool

    public init(tapComplete: Bool = false,
                doubleFlipComplete: Bool = false,
                orbitSwapComplete: Bool = false,
                hasSeenCurrency: Bool = false,
                hasSeenPremiumStore: Bool = false) {
        self.tapComplete = tapComplete
        self.doubleFlipComplete = doubleFlipComplete
        self.orbitSwapComplete = orbitSwapComplete
        self.hasSeenCurrency = hasSeenCurrency
        self.hasSeenPremiumStore = hasSeenPremiumStore
    }

    public var isComplete: Bool {
        tapComplete && doubleFlipComplete && orbitSwapComplete
    }
}

public struct PlayerEntitlements: Codable {
    public static let defaultSkinIdentifier = "default_pod"

    public var removeAds: Bool
    public var ownedSkins: Set<String>
    public var equippedSkin: String
    public var consumableInventory: [String: Int]

    public init(removeAds: Bool = false,
                ownedSkins: Set<String> = [PlayerEntitlements.defaultSkinIdentifier],
                equippedSkin: String = PlayerEntitlements.defaultSkinIdentifier,
                consumableInventory: [String: Int] = [:]) {
        self.removeAds = removeAds
        self.ownedSkins = ownedSkins
        self.equippedSkin = equippedSkin
        self.consumableInventory = consumableInventory
    }

    public mutating func unlockSkin(_ identifier: String) {
        ownedSkins.insert(identifier)
    }

    public mutating func equipSkin(_ identifier: String) {
        guard ownedSkins.contains(identifier) else { return }
        equippedSkin = identifier
    }

    public mutating func addConsumable(_ identifier: String, count: Int = 1) {
        consumableInventory[identifier, default: 0] += count
    }

    public mutating func consume(_ identifier: String) -> Bool {
        guard let count = consumableInventory[identifier], count > 0 else { return false }
        consumableInventory[identifier] = count - 1
        return true
    }
}

public final class GameData {
    public static let shared = GameData()

    private enum Keys {
        static let highScore = "com.orbitflip.highscore"
        static let gems = "com.orbitflip.gems"
        static let streak = "com.orbitflip.streak"
        static let lastStarterPackPrompt = "com.orbitflip.starterpack.prompt"
        static let entitlements = "com.orbitflip.entitlements"
        static let onboarding = "com.orbitflip.onboarding"
    }

    private let defaults: UserDefaults
    private weak var remoteConfig: RemoteConfigProviding?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bootstrapStreakIfNeeded()
        bootstrapEntitlementsIfNeeded()
    }

    public var highScore: Int {
        get { defaults.integer(forKey: Keys.highScore) }
        set { defaults.set(newValue, forKey: Keys.highScore) }
    }

    public var gems: Int {
        get { defaults.integer(forKey: Keys.gems) }
        set { defaults.set(newValue, forKey: Keys.gems) }
    }

    public var entitlements: PlayerEntitlements {
        get {
            guard let data = defaults.data(forKey: Keys.entitlements),
                  let entitlements = try? JSONDecoder().decode(PlayerEntitlements.self, from: data) else {
                return PlayerEntitlements()
            }
            return entitlements
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.entitlements)
            }
        }
    }

    public var onboardingState: OnboardingState {
        get {
            guard let data = defaults.data(forKey: Keys.onboarding),
                  let state = try? JSONDecoder().decode(OnboardingState.self, from: data) else {
                return OnboardingState()
            }
            return state
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.onboarding)
            }
        }
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

    public func configure(remoteConfig: RemoteConfigProviding) {
        self.remoteConfig = remoteConfig
    }

    public func consumeMultiplierBonus() {
        var streak = dailyStreak
        streak.multiplierActiveUntil = nil
        dailyStreak = streak
    }

    public func grantGems(_ amount: Int) {
        guard amount > 0 else { return }
        gems += amount
    }

    @discardableResult
    public func spendGems(_ amount: Int) -> Bool {
        guard amount > 0, gems >= amount else { return false }
        gems -= amount
        return true
    }

    public func canAfford(_ amount: Int) -> Bool {
        gems >= amount
    }

    private func bootstrapStreakIfNeeded() {
        if defaults.data(forKey: Keys.streak) == nil {
            dailyStreak = DailyStreak(streakDays: 1, lastDate: Date())
        }
    }

    private func bootstrapEntitlementsIfNeeded() {
        if defaults.data(forKey: Keys.entitlements) == nil {
            entitlements = PlayerEntitlements()
        }
        if defaults.data(forKey: Keys.onboarding) == nil {
            onboardingState = OnboardingState()
        }
    }

    public func shouldOfferStarterPack() -> Bool {
        guard let lastPrompt = defaults.object(forKey: Keys.lastStarterPackPrompt) as? Date else {
            return true
        }
        let hours = remoteConfig?.starterPackCooldownHours ?? 24
        return Date().timeIntervalSince(lastPrompt) > hours * 60 * 60
    }

    public func markStarterPackPrompted() {
        defaults.set(Date(), forKey: Keys.lastStarterPackPrompt)
    }

    public func starterPackCooldownRemaining() -> TimeInterval {
        guard let lastPrompt = defaults.object(forKey: Keys.lastStarterPackPrompt) as? Date else {
            return 0
        }
        let elapsed = Date().timeIntervalSince(lastPrompt)
        let hours = remoteConfig?.starterPackCooldownHours ?? 24
        return max(0, hours * 60 * 60 - elapsed)
    }

    public func multiplierTimeRemaining() -> TimeInterval? {
        guard let until = dailyStreak.multiplierActiveUntil else { return nil }
        return max(0, until.timeIntervalSince(Date()))
    }

    public var removeAdsUnlocked: Bool {
        entitlements.removeAds
    }

    @discardableResult
    public func applyPurchase(product: PurchaseManager.ProductID) -> PurchaseReward {
        switch product {
        case .removeAds:
            updateEntitlements { $0.removeAds = true }
            return .removeAds
        case .starterPack:
            grantGems(GameConstants.starterPackGemGrant)
            updateEntitlements { entitlements in
                entitlements.unlockSkin(GameConstants.starterPackSkinIdentifier)
                entitlements.equipSkin(GameConstants.starterPackSkinIdentifier)
            }
            markStarterPackPrompted()
            return .starterPack(gems: GameConstants.starterPackGemGrant, skinIdentifier: GameConstants.starterPackSkinIdentifier)
        case .gems100:
            grantGems(100)
            return .gems(amount: 100)
        case .gems550:
            grantGems(550)
            return .gems(amount: 550)
        case .gems1200:
            grantGems(1200)
            return .gems(amount: 1200)
        case .gems3000:
            grantGems(3000)
            return .gems(amount: 3000)
        }
    }

    public func applyRestoredPurchase(product: PurchaseManager.ProductID) -> RestoreOutcome? {
        switch product {
        case .removeAds:
            updateEntitlements { $0.removeAds = true }
            return .removeAds
        case .starterPack:
            updateEntitlements { entitlements in
                entitlements.unlockSkin(GameConstants.starterPackSkinIdentifier)
                if entitlements.equippedSkin == PlayerEntitlements.defaultSkinIdentifier {
                    entitlements.equipSkin(GameConstants.starterPackSkinIdentifier)
                }
            }
            markStarterPackPrompted()
            return .starterPackSkin(identifier: GameConstants.starterPackSkinIdentifier)
        case .gems100, .gems550, .gems1200, .gems3000:
            return nil
        }
    }

    public func unlockCosmetic(_ identifier: String) {
        updateEntitlements { $0.unlockSkin(identifier) }
    }

    public func equipCosmetic(_ identifier: String) {
        updateEntitlements { $0.equipSkin(identifier) }
    }

    public func hasCosmetic(_ identifier: String) -> Bool {
        entitlements.ownedSkins.contains(identifier)
    }

    public var equippedCosmetic: String {
        entitlements.equippedSkin
    }

    public func addConsumable(_ identifier: String, count: Int = 1) {
        updateEntitlements { $0.addConsumable(identifier, count: count) }
    }

    @discardableResult
    public func consumeConsumable(_ identifier: String) -> Bool {
        var consumed = false
        updateEntitlements { entitlements in
            consumed = entitlements.consume(identifier)
        }
        return consumed
    }

    private func updateEntitlements(_ block: (inout PlayerEntitlements) -> Void) {
        var current = entitlements
        block(&current)
        entitlements = current
    }
}

public enum PurchaseReward {
    case removeAds
    case starterPack(gems: Int, skinIdentifier: String)
    case gems(amount: Int)
}

public enum RestoreOutcome {
    case removeAds
    case starterPackSkin(identifier: String)
}

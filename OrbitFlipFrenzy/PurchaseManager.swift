import Foundation
import StoreKit
import UIKit

public protocol PurchaseManaging: AnyObject {
    typealias ProductID = PurchaseManager.ProductID
    typealias StoreProduct = PurchaseManager.StoreProduct

    @discardableResult
    func observeProducts(_ observer: @escaping ([StoreProduct]) -> Void) -> UUID
    func removeObserver(_ token: UUID)
    func presentStorefront(for productID: ProductID, from controller: UIViewController)
    func presentRestorePurchases(from controller: UIViewController)
    func localizedPrice(for productID: ProductID) -> String?
    func refreshProducts()
}

public final class PurchaseManager: PurchaseManaging {
    public enum ProductID: String, CaseIterable {
        case removeAds = "com.orbitflip.remove_ads"
        case starterPack = "com.orbitflip.starter_pack"
        case gems100 = "com.orbitflip.gems_100"
        case gems550 = "com.orbitflip.gems_550"
        case gems1200 = "com.orbitflip.gems_1200"

        var displayName: String {
            switch self {
            case .removeAds:
                return "Remove Ads"
            case .starterPack:
                return "Starter Pack"
            case .gems100:
                return "100 Gems"
            case .gems550:
                return "550 Gems"
            case .gems1200:
                return "1200 Gems"
            }
        }

        var marketingDescription: String {
            switch self {
            case .removeAds:
                return "Play uninterrupted with optional rewarded placements."
            case .starterPack:
                return "Unlock Nova Pod skin + \(GameConstants.starterPackGemGrant) gems."
            case .gems100:
                return "Kickstart your collection with a quick boost."
            case .gems550:
                return "+10% bonus gems to chase rare cosmetics."
            case .gems1200:
                return "+20% bonus gems for long-term upgrades."
            }
        }

        var defaultStoreIdentifier: String { rawValue }

        var configKey: String {
            switch self {
            case .removeAds:
                return "removeAds"
            case .starterPack:
                return "starterPack"
            case .gems100:
                return "gems100"
            case .gems550:
                return "gems550"
            case .gems1200:
                return "gems1200"
            }
        }

        static func fromConfigKey(_ key: String) -> ProductID? {
            ProductID.allCases.first(where: { $0.configKey.caseInsensitiveCompare(key) == .orderedSame })
        }

        var defaultPrice: String {
            switch self {
            case .removeAds:
                return "$2.99"
            case .starterPack:
                return "$0.99"
            case .gems100:
                return "$0.99"
            case .gems550:
                return "$4.99"
            case .gems1200:
                return "$9.99"
            }
        }

        var gemGrant: Int? {
            switch self {
            case .gems100:
                return 100
            case .gems550:
                return 550
            case .gems1200:
                return 1200
            case .starterPack:
                return GameConstants.starterPackGemGrant
            case .removeAds:
                return nil
            }
        }

        var sortIndex: Int {
            switch self {
            case .starterPack:
                return 0
            case .removeAds:
                return 1
            case .gems100:
                return 2
            case .gems550:
                return 3
            case .gems1200:
                return 4
            }
        }

        init?(displayName: String) {
            guard let match = ProductID.allCases.first(where: { $0.displayName.caseInsensitiveCompare(displayName) == .orderedSame }) else {
                return nil
            }
            self = match
        }
    }

    public struct StoreProduct {
        public let id: ProductID
        public let title: String
        public let description: String
        public let price: String
        public let rawPrice: Decimal?
        public let storeIdentifier: String

        public init(id: ProductID,
                    title: String,
                    description: String,
                    price: String,
                    rawPrice: Decimal?,
                    storeIdentifier: String) {
            self.id = id
            self.title = title
            self.description = description
            self.price = price
            self.rawPrice = rawPrice
            self.storeIdentifier = storeIdentifier
        }
    }

    public enum PurchaseError: Error {
        case productUnavailable
        case cancelled
        case pending
        case unknown(String)
    }

    private let data: GameData
    private let analytics: AnalyticsTracking
    private let remoteConfig: RemoteConfigProviding?
    private var observers: [UUID: ([StoreProduct]) -> Void] = [:]
    private var storeProducts: [StoreProduct] = [] {
        didSet { notifyObservers() }
    }
    private var productMap: [ProductID: Product] = [:]
    private var updatesTask: Task<Void, Never>?
    private let queue = DispatchQueue(label: "com.orbitflip.purchase", qos: .userInitiated)
    private var configObserver: UUID?

    public init(data: GameData = .shared,
                analytics: AnalyticsTracking,
                remoteConfig: RemoteConfigProviding? = nil) {
        self.data = data
        self.analytics = analytics
        self.remoteConfig = remoteConfig
        if let remoteConfig {
            configObserver = remoteConfig.addObserver { [weak self] in
                self?.refreshProducts()
            }
        } else {
            configObserver = nil
        }
        refreshProducts()
        listenForTransactions()
    }

    deinit {
        updatesTask?.cancel()
        if let token = configObserver {
            remoteConfig?.removeObserver(token)
        }
    }

    public func refreshProducts() {
        Task { [weak self] in
            guard let self else { return }
            await self.loadProducts()
        }
    }

    @discardableResult
    public func observeProducts(_ observer: @escaping ([StoreProduct]) -> Void) -> UUID {
        let token = UUID()
        observers[token] = observer
        observer(storeProducts)
        return token
    }

    public func removeObserver(_ token: UUID) {
        observers.removeValue(forKey: token)
    }

    public func presentStorefront(for productID: ProductID, from controller: UIViewController) {
        let product = storeProducts.first { $0.id == productID } ?? fallbackProduct(for: productID)
        let alert = UIAlertController(title: product.title,
                                      message: product.description,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        let actionTitle = product.price.isEmpty ? "Buy" : "Buy \(product.price)"
        alert.addAction(UIAlertAction(title: actionTitle, style: .default) { [weak self, weak controller] _ in
            guard let controller, let self else { return }
            self.startPurchaseFlow(for: productID, from: controller)
        })
        controller.present(alert, animated: true)
    }

    public func presentRestorePurchases(from controller: UIViewController) {
        guard #available(iOS 15.0, *) else {
            presentFailure(message: "Restoring purchases requires iOS 15 or later.", from: controller)
            analytics.track(.restoreFailed(reason: "unsupported_os"))
            return
        }
        let loading = UIAlertController(title: "Restoring Purchases",
                                        message: "\n",
                                        preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        loading.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: loading.view.centerXAnchor),
            indicator.bottomAnchor.constraint(equalTo: loading.view.bottomAnchor, constant: -20)
        ])
        indicator.startAnimating()
        controller.present(loading, animated: true)
        Task { [weak self, weak controller] in
            guard let self, let controller else { return }
            do {
                let result = try await self.restoreEntitlements()
                await MainActor.run {
                    loading.dismiss(animated: true) {
                        self.presentRestoreOutcome(result, from: controller)
                    }
                }
                let identifiers = Array(result.restored.map { $0.configKey })
                self.analytics.track(.purchasesRestored(productIDs: identifiers))
            } catch {
                await MainActor.run {
                    loading.dismiss(animated: true) {
                        self.presentFailure(message: error.localizedDescription, from: controller)
                    }
                }
                self.analytics.track(.restoreFailed(reason: error.localizedDescription))
            }
        }
    }

    public func localizedPrice(for productID: ProductID) -> String? {
        storeProducts.first { $0.id == productID }?.price
    }

    private func startPurchaseFlow(for productID: ProductID, from controller: UIViewController) {
        let loading = UIAlertController(title: "Purchasing...", message: "", preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        loading.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: loading.view.centerXAnchor),
            indicator.bottomAnchor.constraint(equalTo: loading.view.bottomAnchor, constant: -20)
        ])
        indicator.startAnimating()
        controller.present(loading, animated: true)

        Task { [weak self, weak controller] in
            guard let self, let controller else { return }
            do {
                let reward = try await self.performPurchase(productID: productID)
                await MainActor.run {
                    loading.dismiss(animated: true) {
                        self.presentSuccess(for: productID, reward: reward, from: controller)
                    }
                }
            } catch PurchaseError.cancelled {
                await MainActor.run {
                    loading.dismiss(animated: true)
                }
            } catch PurchaseError.pending {
                await MainActor.run {
                    loading.dismiss(animated: true) {
                        self.presentPendingNotice(from: controller)
                    }
                }
            } catch {
                await MainActor.run {
                    loading.dismiss(animated: true) {
                        self.presentFailure(message: error.localizedDescription, from: controller)
                    }
                }
            }
        }
    }

    private func presentSuccess(for productID: ProductID, reward: PurchaseReward, from controller: UIViewController) {
        let message: String
        switch reward {
        case .removeAds:
            message = "Ads disabled. Rewarded placements remain opt-in."
        case let .starterPack(gems, skinIdentifier):
            message = "Starter Pack unlocked! +\(gems) gems and \(skinIdentifier.replacingOccurrences(of: "_", with: " ").capitalized) equipped."
        case let .gems(amount):
            message = "Added \(amount) gems to your balance."
        }
        let alert = UIAlertController(title: "Purchase Complete", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Great!", style: .default))
        controller.present(alert, animated: true)
    }

    private func presentFailure(message: String, from controller: UIViewController) {
        let alert = UIAlertController(title: "Purchase Failed",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        controller.present(alert, animated: true)
    }

    private func presentPendingNotice(from controller: UIViewController) {
        let alert = UIAlertController(title: "Purchase Pending",
                                      message: "We'll grant your items once the transaction completes.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Understood", style: .default))
        controller.present(alert, animated: true)
    }

    private func notifyObservers() {
        let snapshot = storeProducts.sorted { $0.id.sortIndex < $1.id.sortIndex }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for observer in self.observers.values {
                observer(snapshot)
            }
        }
    }

    private func fallbackProducts() -> [StoreProduct] {
        ProductID.allCases.map { fallbackProduct(for: $0) }
    }

    private func fallbackProduct(for id: ProductID) -> StoreProduct {
        let override = remoteConfig?.merchandising(for: id)
        StoreProduct(id: id,
                     title: id.displayName,
                     description: override?.marketingMessage ?? id.marketingDescription,
                     price: override?.priceOverride ?? id.defaultPrice,
                     rawPrice: nil,
                     storeIdentifier: remoteConfig?.storeIdentifier(for: id) ?? id.defaultStoreIdentifier)
    }

    private func listenForTransactions() {
        guard #available(iOS 15.0, *) else { return }
        updatesTask = Task.detached { [weak self] in
            for await verificationResult in Transaction.updates {
                guard let self else { continue }
                do {
                    let transaction = try self.checkVerified(verificationResult)
                    guard let productID = self.canonicalProductID(for: transaction.productID) else {
                        await transaction.finish()
                        continue
                    }
                    let reward = self.data.applyPurchase(product: productID)
                    let price = await MainActor.run { self.storeProducts.first(where: { $0.id == productID })?.rawPrice }
                    let storeID = self.remoteConfig?.storeIdentifier(for: productID) ?? productID.defaultStoreIdentifier
                    self.analytics.track(.purchaseCompleted(productID: storeID, canonicalID: productID.configKey, price: price))
                    if case let .gems(amount) = reward {
                        self.analytics.track(.gemsEarned(amount: amount, source: "purchase_restore"))
                    }
                    await transaction.finish()
                } catch {
                    self.analytics.track(.purchaseFailed(productID: "unknown", canonicalID: nil, reason: error.localizedDescription))
                }
            }
        }
    }

    private func loadProducts() async {
        guard #available(iOS 15.0, *) else {
            storeProducts = fallbackProducts()
            return
        }
        do {
            let identifiers = Set(ProductID.allCases.map { remoteConfig?.storeIdentifier(for: $0) ?? $0.defaultStoreIdentifier })
            let products = try await Product.products(for: identifiers)
            var mapped: [StoreProduct] = []
            var map: [ProductID: Product] = [:]
            for product in products {
                guard let id = canonicalProductID(for: product.id) else { continue }
                map[id] = product
                let merchandising = remoteConfig?.merchandising(for: id)
                mapped.append(StoreProduct(id: id,
                                           title: product.displayName,
                                           description: merchandising?.marketingMessage ?? product.description,
                                           price: merchandising?.priceOverride ?? product.displayPrice,
                                           rawPrice: product.price,
                                           storeIdentifier: product.id))
            }
            if mapped.isEmpty {
                mapped = fallbackProducts()
            }
            await MainActor.run {
                self.productMap = map
                self.storeProducts = mapped.sorted { $0.id.sortIndex < $1.id.sortIndex }
            }
        } catch {
            analytics.track(.monetizationError(message: "Product fetch failed: \(error.localizedDescription)"))
            await MainActor.run {
                self.storeProducts = self.fallbackProducts()
            }
        }
    }

    private func performPurchase(productID: ProductID) async throws -> PurchaseReward {
        if #available(iOS 15.0, *) {
            let product: Product
            if let cached = productMap[productID] {
                product = cached
            } else if let fetched = try await fetchProduct(for: productID) {
                product = fetched
            } else {
                let storeID = remoteConfig?.storeIdentifier(for: productID) ?? productID.defaultStoreIdentifier
                analytics.track(.purchaseFailed(productID: storeID, canonicalID: productID.configKey, reason: "unavailable"))
                throw PurchaseError.productUnavailable
            }
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                let transaction = try checkVerified(verification)
                let reward = data.applyPurchase(product: productID)
                let storeID = remoteConfig?.storeIdentifier(for: productID) ?? productID.defaultStoreIdentifier
                analytics.track(.purchaseCompleted(productID: storeID, canonicalID: productID.configKey, price: product.price))
                trackRewardIfNeeded(reward, source: "purchase")
                await transaction.finish()
                return reward
            case .userCancelled:
                let storeID = remoteConfig?.storeIdentifier(for: productID) ?? productID.defaultStoreIdentifier
                analytics.track(.purchaseFailed(productID: storeID, canonicalID: productID.configKey, reason: "cancelled"))
                throw PurchaseError.cancelled
            case .pending:
                let storeID = remoteConfig?.storeIdentifier(for: productID) ?? productID.defaultStoreIdentifier
                analytics.track(.purchaseFailed(productID: storeID, canonicalID: productID.configKey, reason: "pending"))
                throw PurchaseError.pending
            @unknown default:
                let storeID = remoteConfig?.storeIdentifier(for: productID) ?? productID.defaultStoreIdentifier
                analytics.track(.purchaseFailed(productID: storeID, canonicalID: productID.configKey, reason: "unknown"))
                throw PurchaseError.unknown("Unknown purchase result")
            }
        } else {
            let reward = data.applyPurchase(product: productID)
            let storeID = remoteConfig?.storeIdentifier(for: productID) ?? productID.defaultStoreIdentifier
            analytics.track(.purchaseCompleted(productID: storeID, canonicalID: productID.configKey, price: nil))
            trackRewardIfNeeded(reward, source: "legacy")
            return reward
        }
    }

    private func trackRewardIfNeeded(_ reward: PurchaseReward, source: String) {
        switch reward {
        case let .gems(amount):
            analytics.track(.gemsEarned(amount: amount, source: source))
        case let .starterPack(gems, _):
            analytics.track(.gemsEarned(amount: gems, source: source))
        case .removeAds:
            break
        }
    }

    @available(iOS 15.0, *)
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .unverified(_, error):
            throw error
        case let .verified(signedType):
            return signedType
        }
    }

    @available(iOS 15.0, *)
    private func fetchProduct(for id: ProductID) async throws -> Product? {
        let identifier = remoteConfig?.storeIdentifier(for: id) ?? id.defaultStoreIdentifier
        let result = try await Product.products(for: [identifier])
        guard let product = result.first(where: { $0.id == identifier }) else { return nil }
        await MainActor.run {
            self.productMap[id] = product
        }
        return product
    }

    private func canonicalProductID(for storeIdentifier: String) -> ProductID? {
        if let remoteConfig, let mapped = remoteConfig.canonicalProductID(for: storeIdentifier) {
            return mapped
        }
        if let match = ProductID.allCases.first(where: { $0.defaultStoreIdentifier == storeIdentifier }) {
            return match
        }
        return ProductID(rawValue: storeIdentifier)
    }

    @available(iOS 15.0, *)
    private func restoreEntitlements() async throws -> (outcomes: [GameData.RestoreOutcome], restored: Set<ProductID>) {
        var restored: Set<ProductID> = []
        var outcomes: [GameData.RestoreOutcome] = []
        for await verification in Transaction.currentEntitlements {
            let transaction = try checkVerified(verification)
            guard let productID = canonicalProductID(for: transaction.productID) else {
                await transaction.finish()
                continue
            }
            restored.insert(productID)
            if let outcome = data.applyRestoredPurchase(product: productID) {
                outcomes.append(outcome)
            }
            await transaction.finish()
        }
        return (outcomes, restored)
    }

    private func presentRestoreOutcome(_ result: (outcomes: [GameData.RestoreOutcome], restored: Set<ProductID>),
                                       from controller: UIViewController) {
        let restoredProducts = result.restored.map { $0.displayName }.sorted()
        let entitlementMessages = result.outcomes.map { outcome -> String in
            switch outcome {
            case .removeAds:
                return "Ads removed across devices."
            case let .starterPackSkin(identifier):
                return "Starter Pack skin \(identifier.replacingOccurrences(of: "_", with: " ").capitalized) unlocked."
            }
        }
        let message: String
        if result.restored.isEmpty {
            message = "No previous purchases found to restore."
        } else if entitlementMessages.isEmpty {
            message = "Purchases restored. Consumable items such as gem packs are not eligible for restore."
        } else {
            var lines = entitlementMessages
            if !restoredProducts.isEmpty {
                lines.insert("Restored: \(restoredProducts.joined(separator: ", ")).", at: 0)
            }
            message = lines.joined(separator: "\n")
        }
        let alert = UIAlertController(title: "Restore Complete",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        controller.present(alert, animated: true)
    }
}

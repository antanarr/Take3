import Foundation

public protocol RemoteConfigProviding: AnyObject {
    typealias ProductID = PurchaseManager.ProductID

    @discardableResult
    func addObserver(_ observer: @escaping () -> Void) -> UUID
    func removeObserver(_ token: UUID)
    func refresh()

    func storeIdentifier(for product: ProductID) -> String
    func canonicalProductID(for storeIdentifier: String) -> ProductID?
    func merchandising(for product: ProductID) -> RemoteConfigManager.ProductMerchandising?
    var heroProduct: ProductID? { get }
    var starterPackCooldownHours: Double { get }
    var analyticsAuthToken: String? { get }
    var analyticsBatchSize: Int { get }
}

public final class RemoteConfigManager: RemoteConfigProviding {
    public struct ProductMerchandising {
        public let marketingMessage: String?
        public let badge: String?
        public let highlight: Bool
        public let priceOverride: String?
    }

    private struct Payload: Codable {
        struct Product: Codable {
            let canonicalID: String
            let storeIdentifier: String?
            let marketingMessage: String?
            let badge: String?
            let highlight: Bool?
            let priceOverride: String?
        }

        struct Offers: Codable {
            let starterPackCooldownHours: Double?
            let heroProduct: String?
        }

        struct Analytics: Codable {
            let authToken: String?
            let batchSize: Int?
        }

        let products: [Product]?
        let offers: Offers?
        let analytics: Analytics?
    }

    private struct ActiveConfig {
        struct ProductOverride {
            let storeIdentifier: String?
            let marketingMessage: String?
            let badge: String?
            let highlight: Bool
            let priceOverride: String?
        }

        var overrides: [ProductID: ProductOverride]
        var storeLookup: [String: ProductID]
        var heroProduct: ProductID?
        var starterPackCooldownHours: Double
        var analyticsAuthToken: String?
        var analyticsBatchSize: Int
    }

    private let endpoint: URL
    private let session: URLSession
    private let queue: DispatchQueue
    private let queueSpecificKey = DispatchSpecificKey<Void>()
    private var observers: [UUID: () -> Void] = [:]
    private var activeConfig: ActiveConfig
    private let storageURL: URL

    public init(endpoint: URL = URL(string: "https://config.orbitflipfrenzy.fake/app.json")!,
                session: URLSession = .shared,
                fileManager: FileManager = .default) {
        self.endpoint = endpoint
        self.session = session
        self.queue = DispatchQueue(label: "com.orbitflip.remoteconfig", qos: .utility)
        self.queue.setSpecific(key: queueSpecificKey, value: ())
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.storageURL = caches.appendingPathComponent("remote_config.json")
        self.activeConfig = ActiveConfig(overrides: [:],
                                         storeLookup: RemoteConfigManager.makeDefaultStoreLookup(),
                                         heroProduct: nil,
                                         starterPackCooldownHours: 24,
                                         analyticsAuthToken: nil,
                                         analyticsBatchSize: 5)
        loadCachedConfig()
    }

    public func refresh() {
        let request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        session.dataTask(with: request) { [weak self] data, _, error in
            guard let self, let data, error == nil else { return }
            do {
                let payload = try JSONDecoder().decode(Payload.self, from: data)
                self.apply(payload)
                try? data.write(to: self.storageURL, options: .atomic)
            } catch {
                // Ignore decode errors; keep existing config
            }
        }.resume()
    }

    @discardableResult
    public func addObserver(_ observer: @escaping () -> Void) -> UUID {
        let token = UUID()
        queue.async { [weak self] in
            self?.observers[token] = observer
        }
        return token
    }

    public func removeObserver(_ token: UUID) {
        queue.async { [weak self] in
            self?.observers.removeValue(forKey: token)
        }
    }

    public func storeIdentifier(for product: ProductID) -> String {
        queue.sync {
            if let override = activeConfig.overrides[product]?.storeIdentifier {
                return override
            }
            return product.defaultStoreIdentifier
        }
    }

    public func canonicalProductID(for storeIdentifier: String) -> ProductID? {
        queue.sync {
            if let mapped = activeConfig.storeLookup[storeIdentifier] {
                return mapped
            }
            return PurchaseManager.ProductID.allCases.first(where: { $0.defaultStoreIdentifier == storeIdentifier })
        }
    }

    public func merchandising(for product: ProductID) -> ProductMerchandising? {
        queue.sync {
            guard let override = activeConfig.overrides[product] else { return nil }
            return ProductMerchandising(marketingMessage: override.marketingMessage,
                                        badge: override.badge,
                                        highlight: override.highlight,
                                        priceOverride: override.priceOverride)
        }
    }

    public var heroProduct: ProductID? {
        queue.sync { activeConfig.heroProduct }
    }

    public var starterPackCooldownHours: Double {
        queue.sync { activeConfig.starterPackCooldownHours }
    }

    public var analyticsAuthToken: String? {
        queue.sync { activeConfig.analyticsAuthToken }
    }

    public var analyticsBatchSize: Int {
        queue.sync { activeConfig.analyticsBatchSize }
    }

    private func loadCachedConfig() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            apply(payload, asynchronously: false)
        } catch {
            // Ignore cached decode errors
        }
    }

    private func apply(_ payload: Payload, asynchronously: Bool = true) {
        let newConfig = makeActiveConfig(from: payload)
        let applyBlock: @Sendable () -> Void = { [weak self] in
            self?.apply(config: newConfig)
        }

        if asynchronously {
            queue.async(execute: applyBlock)
        } else if DispatchQueue.getSpecific(key: queueSpecificKey) != nil {
            applyBlock()
        } else {
            queue.sync(execute: applyBlock)
        }
    }

    private func makeActiveConfig(from payload: Payload) -> ActiveConfig {
        var overrides: [ProductID: ActiveConfig.ProductOverride] = [:]
        var lookup = RemoteConfigManager.makeDefaultStoreLookup()
        if let products = payload.products {
            for product in products {
                guard let productID = ProductID.fromConfigKey(product.canonicalID) else { continue }
                let override = ActiveConfig.ProductOverride(storeIdentifier: product.storeIdentifier,
                                                             marketingMessage: product.marketingMessage,
                                                             badge: product.badge,
                                                             highlight: product.highlight ?? false,
                                                             priceOverride: product.priceOverride)
                overrides[productID] = override
                if let storeIdentifier = product.storeIdentifier {
                    lookup[storeIdentifier] = productID
                }
            }
        }
        let hero: ProductID?
        if let heroKey = payload.offers?.heroProduct {
            hero = ProductID.fromConfigKey(heroKey)
        } else {
            hero = nil
        }
        let cooldown = payload.offers?.starterPackCooldownHours ?? 24
        let analyticsToken = payload.analytics?.authToken
        let batchSize = max(1, payload.analytics?.batchSize ?? 5)

        return ActiveConfig(overrides: overrides,
                            storeLookup: lookup,
                            heroProduct: hero,
                            starterPackCooldownHours: cooldown,
                            analyticsAuthToken: analyticsToken,
                            analyticsBatchSize: batchSize)
    }

    private func apply(config: ActiveConfig) {
        activeConfig = config
        notifyObservers()
    }

    private func notifyObservers() {
        queue.async { [weak self] in
            guard let self else { return }
            let observers = Array(self.observers.values)
            DispatchQueue.main.async {
                observers.forEach { $0() }
            }
        }
    }

    private static func makeDefaultStoreLookup() -> [String: ProductID] {
        var lookup: [String: ProductID] = [:]
        for product in ProductID.allCases {
            lookup[product.defaultStoreIdentifier] = product
        }
        return lookup
    }
}

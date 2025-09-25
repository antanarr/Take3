import Foundation

public enum AnalyticsEvent: CustomStringConvertible {
    case gameStart(level: Int)
    case gameOver(score: Int, duration: TimeInterval)
    case nearMiss(count: Int)
    case powerupUsed(type: PowerUp)
    case adWatched(placement: String)
    case shareInitiated
    case shareCompleted(activity: String?)
    case shareCancelled
    case purchaseCompleted(productID: String, canonicalID: String?, price: Decimal?)
    case purchaseFailed(productID: String, canonicalID: String?, reason: String)
    case purchasesRestored(productIDs: [String])
    case restoreFailed(reason: String)
    case gemsSpent(amount: Int, reason: String)
    case gemsEarned(amount: Int, source: String)
    case monetizationError(message: String)

    public var name: String {
        switch self {
        case .gameStart:
            return "game_start"
        case .gameOver:
            return "game_over"
        case .nearMiss:
            return "near_miss"
        case .powerupUsed:
            return "powerup_used"
        case .adWatched:
            return "ad_watched"
        case .shareInitiated:
            return "share_initiated"
        case .shareCompleted:
            return "share_completed"
        case .shareCancelled:
            return "share_cancelled"
        case .purchaseCompleted:
            return "purchase_completed"
        case .purchaseFailed:
            return "purchase_failed"
        case .purchasesRestored:
            return "purchases_restored"
        case .restoreFailed:
            return "restore_failed"
        case .gemsSpent:
            return "gems_spent"
        case .gemsEarned:
            return "gems_earned"
        case .monetizationError:
            return "monetization_error"
        }
    }

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
        case let .shareCompleted(activity):
            if let activity {
                return "shareCompleted(activity: \(activity))"
            }
            return "shareCompleted(activity: none)"
        case .shareCancelled:
            return "shareCancelled"
        case let .purchaseCompleted(productID, canonicalID, price):
            var components: [String] = ["id: \(productID)"]
            if let canonicalID { components.append("canonical: \(canonicalID)") }
            if let price { components.append("price: \(price)") }
            return "purchaseCompleted(\(components.joined(separator: ", ")))"
        case let .purchaseFailed(productID, canonicalID, reason):
            var components: [String] = ["id: \(productID)", "reason: \(reason)"]
            if let canonicalID { components.append("canonical: \(canonicalID)") }
            return "purchaseFailed(\(components.joined(separator: ", ")))"
        case let .purchasesRestored(productIDs):
            return "purchasesRestored(ids: \(productIDs.joined(separator: ",")))"
        case let .restoreFailed(reason):
            return "restoreFailed(reason: \(reason))"
        case let .gemsSpent(amount, reason):
            return "gemsSpent(amount: \(amount), reason: \(reason))"
        case let .gemsEarned(amount, source):
            return "gemsEarned(amount: \(amount), source: \(source))"
        case let .monetizationError(message):
            return "monetizationError(\(message))"
        }
    }

    public var parameters: [String: String] {
        switch self {
        case let .gameStart(level):
            return ["level": "\(level)"]
        case let .gameOver(score, duration):
            return ["score": "\(score)", "duration": String(format: "%.2f", duration)]
        case let .nearMiss(count):
            return ["count": "\(count)"]
        case let .powerupUsed(type):
            return ["powerup": type.type.rawValue]
        case let .adWatched(placement):
            return ["placement": placement]
        case .shareInitiated:
            return [:]
        case let .shareCompleted(activity):
            var params: [String: String] = ["status": "completed"]
            if let activity { params["activity"] = activity }
            return params
        case .shareCancelled:
            return ["status": "cancelled"]
        case let .purchaseCompleted(productID, canonicalID, price):
            var params = ["product_id": productID]
            if let canonicalID { params["canonical_id"] = canonicalID }
            if let price {
                params["price"] = NSDecimalNumber(decimal: price).stringValue
            }
            return params
        case let .purchaseFailed(productID, canonicalID, reason):
            var params = ["product_id": productID, "reason": reason]
            if let canonicalID { params["canonical_id"] = canonicalID }
            return params
        case let .purchasesRestored(productIDs):
            return ["product_ids": productIDs.joined(separator: ",")]
        case let .restoreFailed(reason):
            return ["reason": reason]
        case let .gemsSpent(amount, reason):
            return ["amount": "\(amount)", "reason": reason]
        case let .gemsEarned(amount, source):
            return ["amount": "\(amount)", "source": source]
        case let .monetizationError(message):
            return ["message": message]
        }
    }
}

public struct AnalyticsPayload: Codable {
    public let name: String
    public let parameters: [String: String]
    public let timestamp: Date
}

public protocol AnalyticsUploading {
    func upload(_ payload: AnalyticsPayload, completion: @escaping (Result<Void, Error>) -> Void)
    func setAuthToken(_ token: String?)
}

public extension AnalyticsUploading {
    func setAuthToken(_ token: String?) {}
}

public final class RemoteAnalyticsUploader: AnalyticsUploading {
    private let endpoint: URL
    private let session: URLSession
    private let queue = DispatchQueue(label: "com.orbitflip.analytics.uploader", qos: .utility)
    private var authToken: String?

    public init(endpoint: URL = URL(string: "https://telemetry.orbitflipfrenzy.fake/api/events")!,
                session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    public func setAuthToken(_ token: String?) {
        queue.async { [weak self] in
            self?.authToken = token
        }
    }

    public func upload(_ payload: AnalyticsPayload, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            var request = URLRequest(url: self.endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = self.authToken {
                request.setValue(token, forHTTPHeaderField: "X-Auth-Token")
            }
            guard let data = try? JSONEncoder().encode(payload) else {
                completion(.failure(NSError(domain: "AnalyticsUploader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Encode failed"])))
                return
            }
            request.httpBody = data
            let task = self.session.dataTask(with: request) { _, response, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    completion(.success(()))
                } else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    completion(.failure(NSError(domain: "AnalyticsUploader", code: status, userInfo: nil)))
                }
            }
            task.resume()
        }
    }
}

public protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

public final class Analytics: AnalyticsTracking {
    private let uploader: AnalyticsUploading
    private let queue = DispatchQueue(label: "com.orbitflip.analytics", qos: .utility)
    private let sessionID = UUID().uuidString
    private var pending: [AnalyticsPayload]
    private var isFlushing = false
    private var batchSize: Int
    private var batchCounter: Int = 0
    private var retryWorkItem: DispatchWorkItem?
    private let storageURL: URL
    private let fileManager: FileManager
    private weak var remoteConfig: RemoteConfigProviding?
    private var configObserver: UUID?

    public init(uploader: AnalyticsUploading = RemoteAnalyticsUploader(),
                remoteConfig: RemoteConfigProviding? = nil,
                fileManager: FileManager = .default) {
        self.uploader = uploader
        self.remoteConfig = remoteConfig
        self.fileManager = fileManager
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.storageURL = caches.appendingPathComponent("analytics_queue.json")
        self.pending = Analytics.loadCachedEvents(from: storageURL)
        self.batchSize = max(1, remoteConfig?.analyticsBatchSize ?? 5)
        if let token = remoteConfig?.analyticsAuthToken {
            uploader.setAuthToken(token)
        }
        configObserver = remoteConfig?.addObserver { [weak self] in
            self?.handleRemoteConfigUpdate()
        }
        flush()
    }

    deinit {
        if let token = configObserver {
            remoteConfig?.removeObserver(token)
        }
        retryWorkItem?.cancel()
    }

    public func track(_ event: AnalyticsEvent) {
        print("Analytics: \(event.description)")
        let enrichedParameters = event.parameters.merging(["session_id": sessionID]) { $1 }
        let payload = AnalyticsPayload(name: event.name,
                                       parameters: enrichedParameters,
                                       timestamp: Date())
        queue.async { [weak self] in
            guard let self else { return }
            self.pending.append(payload)
            self.persistPending()
            self.flush()
        }
    }

    private static func loadCachedEvents(from url: URL) -> [AnalyticsPayload] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([AnalyticsPayload].self, from: data)) ?? []
    }

    private func persistPending() {
        do {
            let data = try JSONEncoder().encode(pending)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Ignore persistence failures; queue will rebuild from memory
        }
    }

    private func flush() {
        guard !isFlushing else { return }
        cancelRetry()
        batchCounter = 0
        flushNext()
    }

    private func flushNext() {
        guard !pending.isEmpty else { return }
        if batchCounter >= batchSize {
            scheduleRetry(delay: 5)
            return
        }
        isFlushing = true
        let payload = pending.first!
        uploader.upload(payload) { [weak self] result in
            guard let self else { return }
            self.queue.async {
                self.isFlushing = false
                switch result {
                case .success:
                    self.pending.removeFirst()
                    self.persistPending()
                    self.batchCounter += 1
                    self.flushNext()
                case .failure:
                    self.scheduleRetry(delay: 10)
                }
            }
        }
    }

    private func scheduleRetry(delay: TimeInterval) {
        if retryWorkItem != nil { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.queue.async {
                self.retryWorkItem = nil
                self.isFlushing = false
                self.batchCounter = 0
                self.flushNext()
            }
        }
        retryWorkItem = workItem
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelRetry() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
    }

    private func handleRemoteConfigUpdate() {
        queue.async { [weak self] in
            guard let self else { return }
            self.batchSize = max(1, self.remoteConfig?.analyticsBatchSize ?? 5)
            self.uploader.setAuthToken(self.remoteConfig?.analyticsAuthToken)
            self.flush()
        }
    }
}

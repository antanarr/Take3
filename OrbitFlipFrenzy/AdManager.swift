import Foundation
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

public protocol AdManaging: AnyObject {
    var isRewardedReady: Bool { get }
    func preload()
    func showRewardedAd(from viewController: UIViewController, completion: @escaping (Result<Void, AdManager.AdError>) -> Void)
}

public final class AdManager: AdManaging {
    public enum AdError: Error, CustomStringConvertible {
        case notReady
        case cancelled
        case failed(String)

        public var description: String {
            switch self {
            case .notReady:
                return "Rewarded ad is not ready to present."
            case .cancelled:
                return "The viewer cancelled the rewarded ad."
            case let .failed(message):
                return message
            }
        }
    }

    private enum State {
        case idle
        case loading
        case ready(RewardedPresenter)
        case failed(String)
    }

    private let adUnitID: String
    private let queue = DispatchQueue(label: "com.orbitflip.admanager", qos: .userInitiated)
    private var state: State = .idle
    private var lastLoadAttempt: Date?

    public init(adUnitID: String = "ca-app-pub-3940256099942544/1712485313") {
        self.adUnitID = adUnitID
        scheduleReload(delay: 0.2)
    }

    public var isRewardedReady: Bool {
        queue.sync {
            if case .ready = state { return true }
            return false
        }
    }

    public func preload() {
        scheduleReload(delay: 0)
    }

    public func showRewardedAd(from viewController: UIViewController,
                               completion: @escaping (Result<Void, AdError>) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            guard case let .ready(presenter) = self.state else {
                completion(.failure(.notReady))
                self.scheduleReload(delay: 0.5)
                return
            }
            self.state = .loading
            presenter.present(from: viewController) { result in
                self.queue.async {
                    switch result {
                    case .success:
                        completion(.success(()))
                        self.state = .idle
                        self.scheduleReload(delay: 1.0)
                    case let .failure(error):
                        if let adError = error as? AdError {
                            completion(.failure(adError))
                        } else if (error as NSError).code == NSUserCancelledError {
                            completion(.failure(.cancelled))
                        } else {
                            completion(.failure(.failed(error.localizedDescription)))
                        }
                        self.state = .idle
                        self.scheduleReload(delay: 2.0)
                    }
                }
            }
        }
    }

    private func scheduleReload(delay: TimeInterval) {
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            if case .loading = self.state { return }
            if case .ready = self.state { return }
            self.loadRewardedAd()
        }
    }

    private func loadRewardedAd() {
        if let lastLoadAttempt, Date().timeIntervalSince(lastLoadAttempt) < 0.5 { return }
        lastLoadAttempt = Date()
        state = .loading
        Task { [weak self] in
            guard let self else { return }
            do {
                let presenter = try await RewardedLoader.load(adUnitID: self.adUnitID)
                self.queue.async {
                    self.state = .ready(presenter)
                }
            } catch {
                self.queue.async {
                    self.state = .failed(error.localizedDescription)
                    self.scheduleReload(delay: 3.0)
                }
            }
        }
    }
}

// MARK: - Rewarded Presentation

private protocol RewardedPresenter {
    func present(from controller: UIViewController, completion: @escaping (Result<Void, Error>) -> Void)
}

private enum RewardedLoader {
    static func load(adUnitID: String) async throws -> RewardedPresenter {
        #if canImport(GoogleMobileAds)
        return try await GoogleRewardedPresenter.load(adUnitID: adUnitID)
        #else
        try await Task.sleep(nanoseconds: 500_000_000)
        return SimulatedRewardedPresenter()
        #endif
    }
}

#if canImport(GoogleMobileAds)
@available(iOS 15.0, *)
private final class GoogleRewardedPresenter: NSObject, RewardedPresenter, GADFullScreenContentDelegate {
    private var rewarded: GADRewardedAd?
    private var completion: ((Result<Void, Error>) -> Void)?

    static func load(adUnitID: String) async throws -> RewardedPresenter {
        try await withCheckedThrowingContinuation { continuation in
            GADRewardedAd.load(withAdUnitID: adUnitID, request: GADRequest()) { ad, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let presenter = GoogleRewardedPresenter(rewarded: ad)
                ad?.fullScreenContentDelegate = presenter
                continuation.resume(returning: presenter)
            }
        }
    }

    init(rewarded: GADRewardedAd?) {
        self.rewarded = rewarded
    }

    func present(from controller: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let rewarded else {
            completion(.failure(AdManager.AdError.failed("Missing rewarded instance")))
            return
        }
        self.completion = completion
        rewarded.present(fromRootViewController: controller) { _ in
            completion(.success(()))
        }
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        completion?(.failure(error))
        completion = nil
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        completion?(.success(()))
        completion = nil
    }
}
#endif

private final class SimulatedRewardedPresenter: RewardedPresenter {
    func present(from controller: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        let alert = UIAlertController(title: "Sponsor Message",
                                      message: "Watch the hologram to revive!",
                                      preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        alert.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            indicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -45)
        ])

        alert.addAction(UIAlertAction(title: "Skip", style: .cancel) { _ in
            completion(.failure(AdManager.AdError.cancelled))
        })

        controller.present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            guard alert.presentingViewController != nil else { return }
            alert.dismiss(animated: true) {
                completion(.success(()))
            }
        }
    }
}

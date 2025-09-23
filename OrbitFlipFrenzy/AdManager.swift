import Foundation
import UIKit
#if canImport(AVKit)
import AVKit
#endif
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
        case loadFailed(String)
        case presentFailed(String)

        public var description: String {
            switch self {
            case .notReady:
                return "Rewarded ad is not ready"
            case .cancelled:
                return "Rewarded view cancelled"
            case let .loadFailed(message):
                return "Failed to load rewarded ad: \(message)"
            case let .presentFailed(message):
                return "Failed to present rewarded ad: \(message)"
            }
        }
    }

    private enum State {
        case idle
        case loading
        case ready(RewardedAdPresenter)
        case failed(String)
    }

    private let adUnitID: String
    private let queue = DispatchQueue(label: "com.orbitflip.admanager")
    private var state: State = .idle
    private var lastLoadAttempt: Date?

    public init(adUnitID: String = "ca-app-pub-3940256099942544/1712485313") { // Google test ad unit
        self.adUnitID = adUnitID
    }

    public var isRewardedReady: Bool {
        queue.sync {
            if case .ready = state { return true }
            return false
        }
    }

    public func preload() {
        queue.async { [weak self] in
            guard let self else { return }
            if case .ready = self.state { return }
            self.loadRewardedAd(delay: 0)
        }
    }

    public func showRewardedAd(from viewController: UIViewController,
                               completion: @escaping (Result<Void, AdError>) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            guard case let .ready(presenter) = self.state else {
                completion(.failure(.notReady))
                self.loadRewardedAd(delay: 0)
                return
            }
            self.state = .loading
            presenter.present(from: viewController) { result in
                self.queue.async {
                    switch result {
                    case .success:
                        completion(.success(()))
                        self.state = .idle
                        self.loadRewardedAd(delay: 1.0)
                    case let .failure(error):
                        if let adError = error as? AdError {
                            completion(.failure(adError))
                        } else if (error as NSError).code == NSUserCancelledError {
                            completion(.failure(.cancelled))
                        } else {
                            completion(.failure(.presentFailed(error.localizedDescription)))
                        }
                        self.state = .idle
                        self.loadRewardedAd(delay: 2.0)
                    }
                }
            }
        }
    }

    private func loadRewardedAd(delay: TimeInterval) {
        if let lastLoadAttempt, Date().timeIntervalSince(lastLoadAttempt) < 1.0 { return }
        lastLoadAttempt = Date()
        state = .loading
        Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard let self else { return }
            do {
                let presenter = try await RewardedAdLoader.load(adUnitID: self.adUnitID)
                self.queue.async {
                    self.state = .ready(presenter)
                }
            } catch {
                self.queue.async {
                    self.state = .failed(error.localizedDescription)
                    self.scheduleRetry()
                }
            }
        }
    }

    private func scheduleRetry() {
        queue.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self else { return }
            if case .ready = self.state { return }
            self.loadRewardedAd(delay: 0)
        }
    }
}

private protocol RewardedAdPresenter {
    func present(from viewController: UIViewController, completion: @escaping (Result<Void, Error>) -> Void)
}

private enum RewardedAdLoader {
    static func load(adUnitID: String) async throws -> RewardedAdPresenter {
        #if canImport(GoogleMobileAds)
        return try await GoogleRewardedAdPresenter.load(adUnitID: adUnitID)
        #else
        try await Task.sleep(nanoseconds: 500_000_000)
        return SimulatedRewardedAdPresenter()
        #endif
    }
}

#if canImport(GoogleMobileAds)
@available(iOS 15.0, *)
private final class GoogleRewardedAdPresenter: NSObject, RewardedAdPresenter, GADFullScreenContentDelegate {
    private var rewardedAd: GADRewardedAd?
    private var completion: ((Result<Void, Error>) -> Void)?

    static func load(adUnitID: String) async throws -> RewardedAdPresenter {
        try await withCheckedThrowingContinuation { continuation in
            GADRewardedAd.load(withAdUnitID: adUnitID, request: GADRequest()) { ad, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let presenter = GoogleRewardedAdPresenter(rewardedAd: ad)
                ad?.fullScreenContentDelegate = presenter
                continuation.resume(returning: presenter)
            }
        }
    }

    init(rewardedAd: GADRewardedAd?) {
        self.rewardedAd = rewardedAd
    }

    func present(from viewController: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let rewardedAd else {
            completion(.failure(AdManager.AdError.notReady))
            return
        }
        self.completion = completion
        rewardedAd.present(fromRootViewController: viewController) { [weak self] in
            self?.completion?(.success(()))
            self?.completion = nil
        }
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        completion?(.failure(error))
        completion = nil
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        if completion != nil {
            completion?(.failure(AdManager.AdError.cancelled))
            completion = nil
        }
    }
}
#endif

private final class SimulatedRewardedAdPresenter: NSObject, RewardedAdPresenter {
    func present(from viewController: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        let controller = SimulatedRewardedViewController(duration: 5.0) { result in
            completion(result)
        }
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        viewController.present(controller, animated: true)
    }
}

private final class SimulatedRewardedViewController: UIViewController {
    private let duration: TimeInterval
    private let completion: (Result<Void, Error>) -> Void
    private var remainingTime: TimeInterval
    private var timer: Timer?

    init(duration: TimeInterval, completion: @escaping (Result<Void, Error>) -> Void) {
        self.duration = duration
        self.completion = completion
        self.remainingTime = duration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.white
        container.layer.cornerRadius = 16
        container.layer.masksToBounds = true
        view.addSubview(container)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Rewarded Experience"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "Watch to continue and claim your revive."
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        let timerLabel = UILabel()
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        timerLabel.textAlignment = .center
        timerLabel.text = formattedTime()

        let cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        container.addSubview(titleLabel)
        container.addSubview(messageLabel)
        container.addSubview(timerLabel)
        container.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            timerLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 16),
            timerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            timerLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            cancelButton.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 20),
            cancelButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            cancelButton.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ])

        startCountdown(label: timerLabel)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    private func startCountdown(label: UILabel) {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, weak label] timer in
            guard let self else { return }
            self.remainingTime -= 1
            if self.remainingTime <= 0 {
                timer.invalidate()
                self.completion(.success(()))
                self.dismiss(animated: true)
            }
            label?.text = self.formattedTime()
        }
    }

    private func formattedTime() -> String {
        String(format: "00:%02d", Int(max(0, remainingTime)))
    }

    @objc private func cancelTapped() {
        timer?.invalidate()
        completion(.failure(AdManager.AdError.cancelled))
        dismiss(animated: true)
    }
}

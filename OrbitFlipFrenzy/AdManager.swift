import Foundation
import UIKit

public protocol AdManaging {
    func showRewardedAd(from viewController: UIViewController, completion: @escaping () -> Void)
    var isRewardedReady: Bool { get }
}

public final class AdManager: AdManaging {
    private var lastShown: Date?
    private var rewardedReady = false
    private var reloadTask: DispatchWorkItem?
    private let warmupDelay: TimeInterval = 2.0

    public init() {
        scheduleRewardedReload()
    }

    public var isRewardedReady: Bool {
        rewardedReady
    }

    public func showRewardedAd(from viewController: UIViewController, completion: @escaping () -> Void) {
        guard rewardedReady else { return }

        rewardedReady = false
        reloadTask?.cancel()
        lastShown = Date()

        let alert = UIAlertController(title: "Rewarded Ad", message: "Watching...", preferredStyle: .alert)
        viewController.present(alert, animated: true)
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])
        spinner.startAnimating()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            alert.dismiss(animated: true) {
                self?.scheduleRewardedReload()
                completion()
            }
        }
    }

    private func scheduleRewardedReload() {
        reloadTask?.cancel()
        rewardedReady = false
        let task = DispatchWorkItem { [weak self] in
            self?.rewardedReady = true
            self?.reloadTask = nil
        }
        reloadTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + warmupDelay, execute: task)
    }
}

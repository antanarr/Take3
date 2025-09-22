import Foundation
import UIKit

public protocol AdManaging {
    func showRewardedAd(from viewController: UIViewController, completion: @escaping () -> Void)
    var isRewardedReady: Bool { get }
}

public final class AdManager: AdManaging {
    private var lastShown: Date?

    public init() {}

    public var isRewardedReady: Bool {
        true
    }

    public func showRewardedAd(from viewController: UIViewController, completion: @escaping () -> Void) {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            alert.dismiss(animated: true) {
                completion()
            }
        }
    }
}

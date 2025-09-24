import Foundation
import SpriteKit
import UIKit

public protocol GameOverSceneDelegate: AnyObject {
    func gameOverSceneDidRequestRetry(_ scene: GameOverScene)
    func gameOverSceneDidRequestRevive(_ scene: GameOverScene)
    func gameOverSceneDidFinishShare(_ scene: GameOverScene)
    func gameOverSceneDidReturnHome(_ scene: GameOverScene)
}

public final class GameOverScene: SKScene {

    public final class ViewModel {
        private let assets: AssetGenerating
        private let adManager: AdManaging
        private let sound: SoundPlaying
        private let haptics: HapticProviding
        private let analytics: AnalyticsTracking
        private let data: GameData

        init(assets: AssetGenerating,
             adManager: AdManaging,
             sound: SoundPlaying,
             haptics: HapticProviding,
             analytics: AnalyticsTracking,
             data: GameData) {
            self.assets = assets
            self.adManager = adManager
            self.sound = sound
            self.haptics = haptics
            self.analytics = analytics
            self.data = data
        }

        func makeButton(title: String, size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode {
            assets.makeButtonNode(text: title, size: size, icon: icon)
        }

        func share(result: GameResult, from controller: UIViewController) {
            analytics.track(.shareInitiated)
            var message = "I flipped out at \(result.score)! 🚀"
            if let challenge = result.challenge, let link = challenge.generateLink() {
                message += " Beat it: \(link.absoluteString)"
            }
            var items: [Any] = [message]
            if let data = result.replayData {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("orbitflip_replay.gif")
                try? data.write(to: url, options: .atomic)
                items.append(url)
            }
            items.append(assets.makeAppIconImage(size: CGSize(width: 256, height: 256)))
            if let challenge = result.challenge, let link = challenge.generateLink() {
                items.append(link)
            }
            let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
            controller.present(activity, animated: true)
        }

        func showRewarded(from controller: UIViewController, completion: @escaping (Result<Void, AdManager.AdError>) -> Void) {
            adManager.showRewardedAd(from: controller) { [weak self] result in
                if case .success = result {
                    self?.analytics.track(.adWatched(placement: "revive"))
                }
                completion(result)
            }
        }

        func playCrashFeedback() {
            sound.play(.collision)
            haptics.collision()
        }

        var rewardedReady: Bool { adManager.isRewardedReady }
        var gemReviveCost: Int { GameConstants.reviveGemCost }

        func canAffordGemRevive() -> Bool { data.canAfford(gemReviveCost) }

        func spendGemsForRevive() -> Bool {
            guard data.spendGems(gemReviveCost) else { return false }
            analytics.track(.gemsSpent(amount: gemReviveCost, reason: "revive"))
            return true
        }

        func currentGemBalance() -> Int { data.gems }
    }

    public weak var overDelegate: GameOverSceneDelegate?

    private let viewModel: ViewModel
    private let assets: AssetGenerating
    private let result: GameResult

    private var shareButton: SKSpriteNode?
    private var continueAdButton: SKSpriteNode?
    private var continueGemButton: SKSpriteNode?
    private var retryButton: SKSpriteNode?
    private var homeButton: SKSpriteNode?
    private var gemBalanceLabel: SKLabelNode?
    private var statusLabel: SKLabelNode?
    private var lastRewardedReady = false
    private var lastGemBalance = 0

    public init(size: CGSize, viewModel: ViewModel, assets: AssetGenerating, result: GameResult) {
        self.viewModel = viewModel
        self.assets = assets
        self.result = result
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = GamePalette.deepNavy
        removeAllChildren()

        addChild(assets.makeBackground(size: CGSize(width: size.width * 2, height: size.height * 2)))
        viewModel.playCrashFeedback()

        configureBranding()
        configureStats()
        configureButtons()
        refreshGemHUD()
        updateRewardedState()
    }

    public override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        updateRewardedState()
        refreshGemHUD()
    }

    private func configureBranding() {
        let logoSize = CGSize(width: min(size.width * 0.6, 320), height: min(size.width * 0.6, 320) * 0.45)
        let logo = assets.makeLogoNode(size: logoSize)
        logo.position = CGPoint(x: 0, y: size.height * 0.3)
        addChild(logo)

        let status = SKLabelNode(fontNamed: "Orbitron-Bold")
        status.fontSize = 22
        status.fontColor = .white
        status.position = CGPoint(x: 0, y: size.height * 0.18)
        status.text = "Orbit destabilized!"
        addChild(status)
        statusLabel = status

        let gemLabel = SKLabelNode(fontNamed: "SFProRounded-Regular")
        gemLabel.fontSize = 16
        gemLabel.fontColor = UIColor.white.withAlphaComponent(0.75)
        gemLabel.position = CGPoint(x: 0, y: size.height * 0.12)
        addChild(gemLabel)
        gemBalanceLabel = gemLabel
    }

    private func configureStats() {
        let badgeSize = CGSize(width: min(size.width * 0.75, 300), height: 72)
        let summary = assets.makeBadgeNode(title: "Score \(result.score)",
                                           subtitle: String(format: "%.0fs • %d near misses", result.duration, result.nearMisses),
                                           size: badgeSize,
                                           icon: .trophy)
        summary.position = CGPoint(x: 0, y: size.height * 0.02)
        addChild(summary)

        let events = result.triggeredEvents.sorted()
        if !events.isEmpty {
            let subtitle = events.map(String.init).joined(separator: ", ")
            let eventBadge = assets.makeBadgeNode(title: "Events",
                                                  subtitle: "Triggered: \(subtitle)",
                                                  size: badgeSize,
                                                  icon: .power)
            eventBadge.position = CGPoint(x: 0, y: -size.height * 0.08)
            addChild(eventBadge)
        }

        if let challenge = result.challenge {
            let subtitle = "Seed \(challenge.seed) • Beat \(challenge.targetScore)"
            let challengeBadge = assets.makeBadgeNode(title: "Challenge",
                                                      subtitle: subtitle,
                                                      size: badgeSize,
                                                      icon: .timer)
            challengeBadge.position = CGPoint(x: 0, y: -size.height * 0.18)
            addChild(challengeBadge)
        }
    }

    private func configureButtons() {
        let adButton = viewModel.makeButton(title: "Watch & Revive", size: CGSize(width: 240, height: 60), icon: .continue)
        adButton.position = CGPoint(x: 0, y: -size.height * 0.22)
        adButton.name = "continue_ad"
        addChild(adButton)
        continueAdButton = adButton

        let gemButton = viewModel.makeButton(title: "Spend Gems (\(viewModel.gemReviveCost))", size: CGSize(width: 260, height: 60), icon: .gems)
        gemButton.position = CGPoint(x: 0, y: -size.height * 0.32)
        gemButton.name = "continue_gems"
        addChild(gemButton)
        continueGemButton = gemButton

        let share = viewModel.makeButton(title: "Share Highlight", size: CGSize(width: 220, height: 56), icon: .share)
        share.position = CGPoint(x: -size.width * 0.25, y: -size.height * 0.42)
        share.name = "share"
        addChild(share)
        shareButton = share

        let retry = viewModel.makeButton(title: "Retry", size: CGSize(width: 200, height: 56), icon: .retry)
        retry.position = CGPoint(x: 0, y: -size.height * 0.42)
        retry.name = "retry"
        addChild(retry)
        retryButton = retry

        let home = viewModel.makeButton(title: "Home", size: CGSize(width: 180, height: 56), icon: .home)
        home.position = CGPoint(x: size.width * 0.25, y: -size.height * 0.42)
        home.name = "home"
        addChild(home)
        homeButton = home
    }

    private func updateRewardedState() {
        let ready = viewModel.rewardedReady
        if ready != lastRewardedReady {
            continueAdButton?.alpha = ready ? 1.0 : 0.4
            statusLabel?.text = ready ? "Revive available" : "Loading sponsor…"
            lastRewardedReady = ready
        }
        continueGemButton?.alpha = viewModel.canAffordGemRevive() ? 1.0 : 0.4
    }

    private func refreshGemHUD() {
        let balance = viewModel.currentGemBalance()
        if balance != lastGemBalance {
            gemBalanceLabel?.text = "Gems available: \(balance)"
            lastGemBalance = balance
        }
    }

    private func handleShare() {
        guard let controller = view?.window?.rootViewController else { return }
        viewModel.share(result: result, from: controller)
        overDelegate?.gameOverSceneDidFinishShare(self)
    }

    private func handleRewardedRevive() {
        guard let controller = view?.window?.rootViewController else { return }
        continueAdButton?.setPressed(true)
        viewModel.showRewarded(from: controller) { [weak self] result in
            guard let self else { return }
            self.continueAdButton?.setPressed(false)
            switch result {
            case .success:
                self.overDelegate?.gameOverSceneDidRequestRevive(self)
            case .failure:
                self.statusLabel?.text = "Sponsor unavailable"
            }
        }
    }

    private func handleGemRevive() {
        guard viewModel.canAffordGemRevive() else {
            statusLabel?.text = "Earn more gems to revive"
            return
        }
        if viewModel.spendGemsForRevive() {
            refreshGemHUD()
            overDelegate?.gameOverSceneDidRequestRevive(self)
        }
    }

    // MARK: - Touch Handling

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        button(at: point)?.setPressed(true)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        let target = button(at: point)
        [shareButton, continueAdButton, continueGemButton, retryButton, homeButton].forEach { $0?.setPressed(false) }

        if target === shareButton {
            handleShare()
            return
        }
        if target === continueAdButton {
            handleRewardedRevive()
            return
        }
        if target === continueGemButton {
            handleGemRevive()
            return
        }
        if target === retryButton {
            overDelegate?.gameOverSceneDidRequestRetry(self)
            return
        }
        if target === homeButton {
            overDelegate?.gameOverSceneDidReturnHome(self)
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        [shareButton, continueAdButton, continueGemButton, retryButton, homeButton].forEach { $0?.setPressed(false) }
    }

    private func button(at point: CGPoint) -> SKSpriteNode? {
        [shareButton, continueAdButton, continueGemButton, retryButton, homeButton].compactMap { $0 }.first(where: { $0.contains(point) })
    }
}

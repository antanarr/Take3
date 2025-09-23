import Foundation
import SpriteKit
import UIKit

public protocol GameOverSceneDelegate: AnyObject {
    func gameOverSceneDidRequestRetry(_ scene: GameOverScene)
    func gameOverSceneDidRequestRevive(_ scene: GameOverScene)
    func gameOverSceneDidFinishShare(_ scene: GameOverScene)
    func gameOverSceneDidReturnHome(_ scene: GameOverScene)
}

public struct Challenge {
    public let seed: UInt32
    public let targetScore: Int

    public init(seed: UInt32 = arc4random(), targetScore: Int) {
        self.seed = seed
        self.targetScore = targetScore
    }

    public func generateLink() -> String {
        "orbitflip://challenge?seed=\(seed)&score=\(targetScore)"
    }
}

public final class GameOverScene: SKScene {

    public final class ViewModel {
        private let assets: AssetGenerating
        private let adManager: AdManaging
        private let sound: SoundPlaying
        private let haptics: HapticProviding
        private let analytics: AnalyticsTracking

        init(assets: AssetGenerating,
             adManager: AdManaging,
             sound: SoundPlaying,
             haptics: HapticProviding,
             analytics: AnalyticsTracking) {
            self.assets = assets
            self.adManager = adManager
            self.sound = sound
            self.haptics = haptics
            self.analytics = analytics
        }

        func makeButton(title: String, size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode {
            assets.makeButtonNode(text: title, size: size, icon: icon)
        }

        func showRewarded(from controller: UIViewController, completion: @escaping () -> Void) {
            adManager.showRewardedAd(from: controller) { [weak self] in
                self?.analytics.track(.adWatched(placement: "continue"))
                completion()
            }
        }

        func playCollisionFeedback() {
            haptics.collision()
            sound.play(.collision)
        }

        func share(result: GameResult, from controller: UIViewController) {
            analytics.track(.shareInitiated)
            var items: [Any] = ["I flipped out at \(result.score)! 🚀"]
            items.append(assets.makeAppIconImage(size: CGSize(width: 256, height: 256)))
            if let data = result.replayData {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("orbitflip.gif")
                try? data.write(to: tempURL)
                items.append(tempURL)
            }
            let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
            controller.present(activity, animated: true)
        }

        var rewardedReady: Bool { adManager.isRewardedReady }
    }

    public weak var overDelegate: GameOverSceneDelegate?

    private let viewModel: ViewModel
    private let assets: AssetGenerating
    private var result: GameResult
    private var shareButton: SKSpriteNode?
    private var retryButton: SKSpriteNode?
    private var continueButton: SKSpriteNode?
    private var homeButton: SKSpriteNode?

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
        addChild(assets.makeBackground(size: view.bounds.size))
        viewModel.playCollisionFeedback()

        let logoWidth = min(view.bounds.width * 0.65, 300)
        let logo = assets.makeLogoNode(size: CGSize(width: logoWidth, height: logoWidth * 0.4))
        logo.position = CGPoint(x: 0, y: view.bounds.height * 0.24)
        logo.alpha = 0
        logo.run(SKAction.fadeIn(withDuration: 0.8))
        addChild(logo)

        let iconSprite = SKSpriteNode(texture: SKTexture(image: assets.makeAppIconImage(size: CGSize(width: 140, height: 140))))
        iconSprite.size = CGSize(width: 96, height: 96)
        iconSprite.position = CGPoint(x: -logoWidth * 0.55, y: logo.position.y)
        iconSprite.alpha = 0
        iconSprite.run(SKAction.sequence([SKAction.wait(forDuration: 0.2), SKAction.fadeIn(withDuration: 0.7)]))
        addChild(iconSprite)

        let headline = SKLabelNode(text: "Don't lose your streak!")
        headline.fontName = "Orbitron-Bold"
        headline.fontSize = 26
        headline.fontColor = GamePalette.solarGold
        headline.position = CGPoint(x: 0, y: logo.position.y - logoWidth * 0.35)
        addChild(headline)

        let statsBadge = assets.makeBadgeNode(title: "Score \(result.score)",
                                              subtitle: "Near-misses \(result.nearMisses) • Time \(String(format: "%.1fs", result.duration))",
                                              size: CGSize(width: min(view.bounds.width * 0.82, 320), height: 78),
                                              icon: .trophy)
        statsBadge.position = CGPoint(x: 0, y: headline.position.y - 80)
        addChild(statsBadge)

        let eventsText = result.triggeredEvents.sorted().map { "#\($0)" }.joined(separator: " ")
        if !eventsText.isEmpty {
            let eventsLabel = SKLabelNode(text: "Moments unlocked: \(eventsText)")
            eventsLabel.fontName = "SFProRounded-Bold"
            eventsLabel.fontColor = GamePalette.neonMagenta
            eventsLabel.fontSize = 16
            eventsLabel.position = CGPoint(x: 0, y: statsBadge.position.y - 70)
            addChild(eventsLabel)
        }

        shareButton = viewModel.makeButton(title: "Share Highlight", size: CGSize(width: 220, height: 60), icon: .share)
        shareButton?.position = CGPoint(x: 0, y: -20)
        shareButton?.name = "share"
        if let shareButton { addChild(shareButton) }

        continueButton = viewModel.makeButton(title: "Watch to Continue", size: CGSize(width: 240, height: 60), icon: .continue)
        continueButton?.position = CGPoint(x: 0, y: shareButton?.position.y ?? -20 - 80)
        continueButton?.name = "continue"
        if let continueButton { addChild(continueButton) }
        continueButton?.alpha = viewModel.rewardedReady ? 1.0 : 0.4

        retryButton = viewModel.makeButton(title: "Retry", size: CGSize(width: 180, height: 60), icon: .retry)
        retryButton?.position = CGPoint(x: 0, y: (continueButton?.position.y ?? -100) - 80)
        retryButton?.name = "retry"
        if let retryButton { addChild(retryButton) }

        homeButton = viewModel.makeButton(title: "Home", size: CGSize(width: 160, height: 54), icon: .home)
        homeButton?.position = CGPoint(x: 0, y: (retryButton?.position.y ?? -180) - 70)
        homeButton?.name = "home"
        if let homeButton { addChild(homeButton) }

        let challenge = Challenge(targetScore: result.score)
        let challengeLabel = SKLabelNode(text: "Challenge friends: \(challenge.generateLink())")
        challengeLabel.fontName = "SFProRounded-Regular"
        challengeLabel.fontColor = UIColor.white.withAlphaComponent(0.7)
        challengeLabel.fontSize = 12
        challengeLabel.position = CGPoint(x: 0, y: (homeButton?.position.y ?? -240) - 50)
        addChild(challengeLabel)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        let nodes = nodes(at: location)
        if let share = shareButton, nodes.contains(share) || nodes.contains(where: { $0.name == "label" && $0.parent == share }) {
            handleShare()
        } else if let retry = retryButton, nodes.contains(retry) || nodes.contains(where: { $0.name == "label" && $0.parent == retry }) {
            overDelegate?.gameOverSceneDidRequestRetry(self)
        } else if let home = homeButton, nodes.contains(home) || nodes.contains(where: { $0.name == "label" && $0.parent == home }) {
            overDelegate?.gameOverSceneDidReturnHome(self)
        } else if let cont = continueButton, nodes.contains(cont) || nodes.contains(where: { $0.name == "label" && $0.parent == cont }) {
            handleContinue()
        }
    }

    private func handleShare() {
        guard let view = view, let controller = view.window?.rootViewController else { return }
        viewModel.share(result: result, from: controller)
        overDelegate?.gameOverSceneDidFinishShare(self)
    }

    private func handleContinue() {
        guard viewModel.rewardedReady, let view = view, let controller = view.window?.rootViewController else { return }
        continueButton?.alpha = 0.4
        viewModel.showRewarded(from: controller) { [weak self] in
            guard let self else { return }
            self.overDelegate?.gameOverSceneDidRequestRevive(self)
        }
    }
}

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

        func makeButton(title: String, size: CGSize) -> SKSpriteNode {
            assets.makeButtonNode(text: title, size: size)
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

        let title = SKLabelNode(text: "Don't lose your streak!")
        title.fontName = "Orbitron-Bold"
        title.fontSize = 28
        title.fontColor = GamePalette.solarGold
        title.position = CGPoint(x: 0, y: view.bounds.height * 0.2)
        addChild(title)

        let scoreNode = SKLabelNode(text: "Score \(result.score)")
        scoreNode.fontName = "Orbitron-Bold"
        scoreNode.fontSize = 40
        scoreNode.fontColor = .white
        scoreNode.position = CGPoint(x: 0, y: title.position.y - 80)
        addChild(scoreNode)

        let statsNode = SKLabelNode(text: "Near-misses: \(result.nearMisses) • Time: \(String(format: "%.1fs", result.duration))")
        statsNode.fontName = "SFProRounded-Bold"
        statsNode.fontColor = GamePalette.cyan
        statsNode.fontSize = 18
        statsNode.position = CGPoint(x: 0, y: scoreNode.position.y - 40)
        addChild(statsNode)

        let eventsText = result.triggeredEvents.sorted().map { "#\($0)" }.joined(separator: " ")
        if !eventsText.isEmpty {
            let eventsLabel = SKLabelNode(text: "Moments unlocked: \(eventsText)")
            eventsLabel.fontName = "SFProRounded-Bold"
            eventsLabel.fontColor = GamePalette.neonMagenta
            eventsLabel.fontSize = 16
            eventsLabel.position = CGPoint(x: 0, y: statsNode.position.y - 40)
            addChild(eventsLabel)
        }

        shareButton = viewModel.makeButton(title: "Share Highlight", size: CGSize(width: 220, height: 60))
        shareButton?.position = CGPoint(x: 0, y: -20)
        shareButton?.name = "share"
        if let shareButton { addChild(shareButton) }

        continueButton = viewModel.makeButton(title: "Watch to Continue", size: CGSize(width: 240, height: 60))
        continueButton?.position = CGPoint(x: 0, y: shareButton?.position.y ?? -20 - 80)
        continueButton?.name = "continue"
        if let continueButton { addChild(continueButton) }
        continueButton?.alpha = viewModel.rewardedReady ? 1.0 : 0.4

        retryButton = viewModel.makeButton(title: "Retry", size: CGSize(width: 180, height: 60))
        retryButton?.position = CGPoint(x: 0, y: (continueButton?.position.y ?? -100) - 80)
        retryButton?.name = "retry"
        if let retryButton { addChild(retryButton) }

        homeButton = viewModel.makeButton(title: "Home", size: CGSize(width: 160, height: 54))
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

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

        func preloadRewarded() {
            adManager.preload()
        }

        func showRewarded(from controller: UIViewController, completion: @escaping (Result<Void, AdManager.AdError>) -> Void) {
            adManager.showRewardedAd(from: controller) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    self.analytics.track(.adWatched(placement: "continue"))
                case let .failure(error):
                    self.analytics.track(.monetizationError(message: "Rewarded failed: \(error.description)"))
                }
                completion(result)
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

        var gemReviveCost: Int { GameConstants.reviveGemCost }

        func canAffordGemRevive() -> Bool {
            data.canAfford(gemReviveCost)
        }

        @discardableResult
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
    private var result: GameResult
    private var shareButton: SKSpriteNode?
    private var retryButton: SKSpriteNode?
    private var continueButton: SKSpriteNode?
    private var homeButton: SKSpriteNode?
    private var gemContinueButton: SKSpriteNode?
    private var gemBalanceLabel: SKLabelNode?
    private var monetizationStatusLabel: SKLabelNode?
    private var meteorEmitter: SKEmitterNode?
    private var lastGemBalance: Int = 0
    private var statusMessageRemaining: TimeInterval = 0
    private var lastRewardedReady: Bool = false
    private var lastUpdateTime: TimeInterval = 0

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
        viewModel.preloadRewarded()

        let meteor = SKEmitterNode()
        meteor.particleTexture = assets.makeParticleTexture(radius: 3, color: GamePalette.cyan)
        meteor.particleBirthRate = 28
        meteor.particleLifetime = 4.5
        meteor.particleLifetimeRange = 1.5
        meteor.particleSpeed = 140
        meteor.particleSpeedRange = 50
        meteor.emissionAngle = CGFloat.pi * 1.12
        meteor.emissionAngleRange = CGFloat.pi / 12
        meteor.particleAlpha = 0.75
        meteor.particleAlphaRange = 0.2
        meteor.particleAlphaSpeed = -0.2
        meteor.particleScale = 0.35
        meteor.particleScaleRange = 0.15
        meteor.particleScaleSpeed = -0.05
        meteor.particleColorBlendFactor = 1.0
        meteor.position = CGPoint(x: view.bounds.width * 0.35, y: view.bounds.height * 0.45)
        meteor.particlePositionRange = CGVector(dx: view.bounds.width * 1.2, dy: view.bounds.height * 0.2)
        meteor.zPosition = -2
        meteor.targetNode = self
        addChild(meteor)
        meteorEmitter = meteor

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


=======
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

        headline.alpha = 0
        headline.run(SKAction.sequence([SKAction.wait(forDuration: 0.3), SKAction.fadeIn(withDuration: 0.6)]))
        addChild(headline)
=======
        addChild(headline)

        let statsBadge = assets.makeBadgeNode(title: "Score \(result.score)",
                                              subtitle: "Near-misses \(result.nearMisses) • Time \(String(format: "%.1fs", result.duration))",
                                              size: CGSize(width: min(view.bounds.width * 0.82, 320), height: 78),
                                              icon: .trophy)
        statsBadge.position = CGPoint(x: 0, y: headline.position.y - 80)
        addChild(statsBadge)


        let gemLabel = SKLabelNode(fontNamed: "Orbitron-Bold")
        gemLabel.fontSize = 18
        gemLabel.fontColor = GamePalette.cyan
        gemLabel.horizontalAlignmentMode = .right
        gemLabel.position = CGPoint(x: view.bounds.width * 0.42, y: logo.position.y + logo.size.height * 0.45)
        gemLabel.text = "Gems: \(viewModel.currentGemBalance())"
        gemLabel.alpha = 0
        gemLabel.run(SKAction.sequence([SKAction.wait(forDuration: 0.4), SKAction.fadeIn(withDuration: 0.6)]))
        addChild(gemLabel)
        gemBalanceLabel = gemLabel
        lastGemBalance = viewModel.currentGemBalance()

        let badgeSize = CGSize(width: min(view.bounds.width * 0.82, 320), height: 78)
        let statsBadge = assets.makeBadgeNode(title: "Score \(result.score)",
                                              subtitle: "Near-misses \(result.nearMisses) • Time \(String(format: "%.1fs", result.duration))",
                                              size: badgeSize,
                                              icon: .trophy)
        statsBadge.position = CGPoint(x: 0, y: headline.position.y - 80)
        statsBadge.alpha = 0
        statsBadge.run(SKAction.sequence([SKAction.wait(forDuration: 0.45), SKAction.fadeIn(withDuration: 0.6)]))
        addChild(statsBadge)

        var nextAnchor = statsBadge.position.y - badgeSize.height * 0.6
        let eventsText = result.triggeredEvents.sorted().map { "#\($0)" }.joined(separator: " ")
        if !eventsText.isEmpty {
            let eventsLabel = SKLabelNode(text: "Moments unlocked: \(eventsText)")
            eventsLabel.fontName = "SFProRounded-Bold"
            eventsLabel.fontColor = GamePalette.neonMagenta
            eventsLabel.fontSize = 16

            eventsLabel.position = CGPoint(x: 0, y: statsBadge.position.y - badgeSize.height * 0.7)
=======
            eventsLabel.position = CGPoint(x: 0, y: statsBadge.position.y - 70)

            addChild(eventsLabel)
            nextAnchor = eventsLabel.position.y - 50
        }


        let buttonAnchor = nextAnchor - 20

        shareButton = viewModel.makeButton(title: "Share Highlight", size: CGSize(width: 220, height: 60))
        shareButton?.position = CGPoint(x: 0, y: buttonAnchor)
        shareButton?.name = "share"
        if let shareButton { addChild(shareButton) }

        continueButton = viewModel.makeButton(title: "Watch to Continue", size: CGSize(width: 240, height: 60))
        continueButton?.position = CGPoint(x: 0, y: (shareButton?.position.y ?? buttonAnchor) - 80)
=======
        shareButton = viewModel.makeButton(title: "Share Highlight", size: CGSize(width: 220, height: 60), icon: .share)
        shareButton?.position = CGPoint(x: 0, y: -20)
        shareButton?.name = "share"
        if let shareButton { addChild(shareButton) }

        continueButton = viewModel.makeButton(title: "Watch to Continue", size: CGSize(width: 240, height: 60), icon: .continue)
        continueButton?.position = CGPoint(x: 0, y: shareButton?.position.y ?? -20 - 80)

        continueButton?.name = "continue"
        if let continueButton { addChild(continueButton) }

        gemContinueButton = viewModel.makeButton(title: "Spend \(viewModel.gemReviveCost) Gems", size: CGSize(width: 260, height: 60))
        gemContinueButton?.position = CGPoint(x: 0, y: (continueButton?.position.y ?? -100) - 80)
        gemContinueButton?.name = "gem_continue"
        if let gemContinueButton { addChild(gemContinueButton) }


        retryButton = viewModel.makeButton(title: "Retry", size: CGSize(width: 180, height: 60))
        retryButton?.position = CGPoint(x: 0, y: (gemContinueButton?.position.y ?? -160) - 80)
=======
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

        let status = SKLabelNode(fontNamed: "SFProRounded-Bold")
        status.fontSize = 16
        status.fontColor = UIColor.white.withAlphaComponent(0.85)
        status.alpha = 0
        status.position = CGPoint(x: 0, y: challengeLabel.position.y - 40)
        addChild(status)
        monetizationStatusLabel = status

        lastRewardedReady = viewModel.rewardedReady
        updateRewardedAvailability()
        updateGemButtonState()
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        let nodes = nodes(at: location)
        if let share = shareButton, nodes.contains(share) || nodes.contains(where: { $0.name == "label" && $0.parent == share }) {
            handleShare()
        } else if let gem = gemContinueButton, nodes.contains(gem) || nodes.contains(where: { $0.name == "label" && $0.parent == gem }) {
            handleGemContinue()
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
        guard let view = view, let controller = view.window?.rootViewController else { return }
        guard viewModel.rewardedReady else {
            showStatusMessage("Ad loading…", success: false)
            viewModel.preloadRewarded()
            return
        }
        continueButton?.alpha = 0.4
        viewModel.showRewarded(from: controller) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.showStatusMessage("Revived via ad!", success: true)
                self.overDelegate?.gameOverSceneDidRequestRevive(self)
            case .failure:
                self.showStatusMessage("Ad unavailable. Try again soon.", success: false)
            }
            self.updateRewardedAvailability()
        }
    }

    private func handleGemContinue() {
        guard viewModel.canAffordGemRevive() else {
            showStatusMessage("Need \(viewModel.gemReviveCost) gems to revive.", success: false)
            return
        }
        if viewModel.spendGemsForRevive() {
            updateGemBalanceIfNeeded()
            updateGemButtonState()
            showStatusMessage("Revived for \(viewModel.gemReviveCost) gems!", success: true)
            overDelegate?.gameOverSceneDidRequestRevive(self)
        } else {
            showStatusMessage("Gem spend failed.", success: false)
        }
    }

    private func updateGemBalanceIfNeeded() {
        let balance = viewModel.currentGemBalance()
        if balance != lastGemBalance {
            lastGemBalance = balance
            gemBalanceLabel?.text = "Gems: \(balance)"
        }
    }

    private func updateGemButtonState() {
        let enabled = viewModel.canAffordGemRevive()
        gemContinueButton?.alpha = enabled ? 1.0 : 0.4
    }

    private func updateRewardedAvailability() {
        let ready = viewModel.rewardedReady
        if ready != lastRewardedReady {
            continueButton?.alpha = ready ? 1.0 : 0.4
            lastRewardedReady = ready
        }
    }

    private func showStatusMessage(_ text: String, success: Bool) {
        guard let label = monetizationStatusLabel else { return }
        label.removeAllActions()
        label.text = text
        label.fontColor = success ? GamePalette.cyan : UIColor.systemRed
        label.alpha = 1.0
        statusMessageRemaining = 2.5
    }

    public override func update(_ currentTime: TimeInterval) {
        updateRewardedAvailability()
        updateGemButtonState()
        updateGemBalanceIfNeeded()
        let delta: TimeInterval
        if lastUpdateTime == 0 {
            delta = 0
        } else {
            delta = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime
        if statusMessageRemaining > 0 {
            statusMessageRemaining = max(0, statusMessageRemaining - delta)
        }
        if statusMessageRemaining == 0, let label = monetizationStatusLabel, label.alpha > 0 {
            label.run(SKAction.fadeOut(withDuration: 0.25))
            statusMessageRemaining = -1
        }
        if let view = view, let emitter = meteorEmitter {
            emitter.position.x -= CGFloat(delta * 40)
            if emitter.position.x < -view.bounds.width * 0.35 {
                emitter.position.x = view.bounds.width * 0.35
            }
        }
    }
}

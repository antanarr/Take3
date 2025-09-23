import Foundation
import SpriteKit
import UIKit

public protocol MenuSceneDelegate: AnyObject {
    func menuSceneDidStartGame(_ scene: MenuScene)
    func menuScene(_ scene: MenuScene, didSelectProduct name: String)
}

public final class MenuScene: SKScene {

    public final class ViewModel {
        struct IAPProduct {
            let title: String
            let price: String
            let description: String
        }

        private let assets: AssetGenerating
        private let data: GameData
        private let sound: SoundPlaying

        init(assets: AssetGenerating, data: GameData, sound: SoundPlaying) {
            self.assets = assets
            self.data = data
            self.sound = sound
        }

        func registerDailyStreak() -> DailyStreak {
            data.registerDailyPlay()
        }

        var highScoreText: String { "Best: \(data.highScore)" }

        var iapProducts: [IAPProduct] {
            return [
                IAPProduct(title: "Remove Ads", price: "$2.99", description: "Fly ad-free forever."),
                IAPProduct(title: "Starter Pack", price: "$0.99", description: "Nova Pod skin + 200 gems"),
                IAPProduct(title: "100 Gems", price: "$0.99", description: "Boost your collection."),
                IAPProduct(title: "550 Gems", price: "$4.99", description: "+10% bonus gems."),
                IAPProduct(title: "1200 Gems", price: "$9.99", description: "+20% bonus gems.")
            ]
        }

        func createButton(title: String, size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode {
            assets.makeButtonNode(text: title, size: size, icon: icon)
        }

        func playStartSound() {
            sound.play(.gameStart)
        }
    }

    public weak var menuDelegate: MenuSceneDelegate?

    private let viewModel: ViewModel
    private let assets: AssetGenerating
    private var startButton: SKSpriteNode?
    public init(size: CGSize, viewModel: ViewModel, assets: AssetGenerating) {
        self.viewModel = viewModel
        self.assets = assets
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = GamePalette.deepNavy

        let background = assets.makeBackground(size: view.bounds.size)
        addChild(background)

        let maxLogoWidth = min(view.bounds.width * 0.75, 360)
        let logoSize = CGSize(width: maxLogoWidth, height: maxLogoWidth * 0.45)
        let logo = assets.makeLogoNode(size: logoSize)
        logo.position = CGPoint(x: 0, y: view.bounds.height * 0.25)
        logo.alpha = 0
        logo.run(SKAction.fadeIn(withDuration: 0.9))
        addChild(logo)

        let iconTexture = SKTexture(image: assets.makeAppIconImage(size: CGSize(width: 160, height: 160)))
        let iconNode = SKSpriteNode(texture: iconTexture)
        iconNode.size = CGSize(width: 108, height: 108)
        iconNode.position = CGPoint(x: -logoSize.width * 0.55, y: logo.position.y + iconNode.size.height * 0.05)
        iconNode.alpha = 0
        iconNode.run(SKAction.sequence([SKAction.wait(forDuration: 0.2), SKAction.fadeIn(withDuration: 0.8)]))
        addChild(iconNode)

        let subtitle = SKLabelNode(text: "Flip faster, dodge harder, own the orbit.")
        subtitle.fontName = "SFProRounded-Bold"
        subtitle.fontSize = 16
        subtitle.fontColor = GamePalette.cyan
        subtitle.position = CGPoint(x: 0, y: logo.position.y - logoSize.height * 0.6)
        subtitle.alpha = 0
        subtitle.run(SKAction.sequence([SKAction.wait(forDuration: 0.35), SKAction.fadeIn(withDuration: 0.8)]))
        addChild(subtitle)

        let start = viewModel.createButton(title: "Tap to Launch", size: CGSize(width: 240, height: 80), icon: .play)
        start.position = CGPoint(x: 0, y: -20)
        start.name = "start"
        start.alpha = 0
        start.run(SKAction.sequence([SKAction.wait(forDuration: 0.6), SKAction.fadeIn(withDuration: 0.6)]))
        addChild(start)
        startButton = start

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.8),
            SKAction.scale(to: 1.0, duration: 0.8)
        ])
        start.run(SKAction.repeatForever(pulse))

        let streak = viewModel.registerDailyStreak()
        let streakNode = assets.makeBadgeNode(title: "Daily Streak: \(streak.streakDays) days",
                                              subtitle: "Reward +\(Int(streak.reward)) gems engaged",
                                              size: CGSize(width: min(view.bounds.width * 0.85, 340), height: 74),
                                              icon: .streak)
        streakNode.position = CGPoint(x: 0, y: -view.bounds.height * 0.18)
        addChild(streakNode)

        let bestBadge = assets.makeBadgeNode(title: viewModel.highScoreText,
                                             subtitle: "Personal Record",
                                             size: CGSize(width: min(view.bounds.width * 0.8, 320), height: 68),
                                             icon: .trophy)
        bestBadge.position = CGPoint(x: 0, y: streakNode.position.y - 90)
        addChild(bestBadge)

        layoutProducts(around: bestBadge.position.y - 80)
    }

    private func layoutProducts(around y: CGFloat) {
        let products = viewModel.iapProducts
        let spacing: CGFloat = 38
        for (index, product) in products.enumerated() {
            let label = SKLabelNode(text: "• \(product.title) — \(product.price)")
            label.fontName = "SFProRounded-Bold"
            label.fontColor = GamePalette.cyan
            label.fontSize = 18
            label.position = CGPoint(x: 0, y: y - CGFloat(index) * spacing)
            label.name = "product_\(product.title)"
            label.userData = ["product": product.title]
            addChild(label)

            let detail = SKLabelNode(text: product.description)
            detail.fontName = "SFProRounded-Regular"
            detail.fontColor = UIColor.white.withAlphaComponent(0.7)
            detail.fontSize = 14
            detail.position = CGPoint(x: 0, y: label.position.y - 18)
            detail.name = "product_detail_\(product.title)"
            detail.userData = ["product": product.title]
            addChild(detail)
        }
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        let nodes = nodes(at: location)
        if let start = startButton, nodes.contains(start) || nodes.contains(where: { $0.name == "label" && $0.parent == start }) {
            startButton?.setPressed(true)
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        startButton?.setPressed(false)
        let nodes = nodes(at: location)
        if let start = startButton, nodes.contains(start) || nodes.contains(where: { $0.name == "label" && $0.parent == start }) {
            viewModel.playStartSound()
            menuDelegate?.menuSceneDidStartGame(self)
            return
        }
        if let label = nodes.compactMap({ $0 as? SKLabelNode }).first,
           let productTitle = label.userData?["product"] as? String {
            menuDelegate?.menuScene(self, didSelectProduct: productTitle)
        }
    }
}

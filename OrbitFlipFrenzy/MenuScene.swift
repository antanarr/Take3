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

        func createButton(title: String, size: CGSize) -> SKSpriteNode {
            assets.makeButtonNode(text: title, size: size)
        }

        func playStartSound() {
            sound.play(.gameStart)
        }
    }

    public weak var menuDelegate: MenuSceneDelegate?

    private let viewModel: ViewModel
    private let assets: AssetGenerating
    private var startButton: SKSpriteNode?
    private var streakLabel: SKLabelNode?

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

        let title = SKLabelNode(text: "Orbit Flip Frenzy")
        title.fontName = "Orbitron-Bold"
        title.fontSize = 42
        title.fontColor = GamePalette.solarGold
        title.position = CGPoint(x: 0, y: view.bounds.height * 0.2)
        title.alpha = 0
        title.run(SKAction.fadeIn(withDuration: 1.0))
        addChild(title)

        let subtitle = SKLabelNode(text: "Flip faster, dodge harder, own the orbit.")
        subtitle.fontName = "SFProRounded-Bold"
        subtitle.fontSize = 16
        subtitle.fontColor = GamePalette.cyan
        subtitle.position = CGPoint(x: 0, y: title.position.y - 60)
        subtitle.alpha = 0
        subtitle.run(SKAction.sequence([SKAction.wait(forDuration: 0.3), SKAction.fadeIn(withDuration: 0.8)]))
        addChild(subtitle)

        let start = viewModel.createButton(title: "Tap to Launch", size: CGSize(width: 240, height: 80))
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
        let streakNode = SKLabelNode(text: "Daily Streak: \(streak.streakDays) days • Reward +\(Int(streak.reward)) gems")
        streakNode.fontName = "SFProRounded-Bold"
        streakNode.fontColor = .white
        streakNode.fontSize = 18
        streakNode.position = CGPoint(x: 0, y: -view.bounds.height * 0.2)
        addChild(streakNode)
        streakLabel = streakNode

        let bestLabel = SKLabelNode(text: viewModel.highScoreText)
        bestLabel.fontName = "Orbitron-Bold"
        bestLabel.fontSize = 18
        bestLabel.fontColor = GamePalette.solarGold
        bestLabel.position = CGPoint(x: 0, y: streakNode.position.y - 40)
        addChild(bestLabel)

        layoutProducts(around: bestLabel.position.y - 60)
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

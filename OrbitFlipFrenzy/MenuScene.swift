import Foundation
import SpriteKit
import UIKit

public protocol MenuSceneDelegate: AnyObject {
    func menuSceneDidStartGame(_ scene: MenuScene)
    func menuScene(_ scene: MenuScene, didSelectProduct name: String)
    func menuSceneDidRequestRestore(_ scene: MenuScene)
}

public final class MenuScene: SKScene {

    public final class ViewModel {
        struct DisplayProduct {
            let title: String
            let price: String
            let detail: String
            let badge: String?
            let highlight: Bool
        }

        private let assets: AssetGenerating
        private let data: GameData
        private let sound: SoundPlaying
        private let purchases: PurchaseManaging
        private let analytics: AnalyticsTracking
        private let remoteConfig: RemoteConfigProviding?
        private var cachedProducts: [PurchaseManaging.StoreProduct] = []
        private var productObserver: UUID?

        init(assets: AssetGenerating,
             data: GameData,
             sound: SoundPlaying,
             purchases: PurchaseManaging,
             analytics: AnalyticsTracking,
             remoteConfig: RemoteConfigProviding?) {
            self.assets = assets
            self.data = data
            self.sound = sound
            self.purchases = purchases
            self.analytics = analytics
            self.remoteConfig = remoteConfig
        }

        deinit {
            if let observer = productObserver {
                purchases.removeObserver(observer)
            }
        }

        func registerDailyStreak() -> DailyStreak {
            let previous = data.gems
            let streak = data.registerDailyPlay()
            let gained = data.gems - previous
            if gained > 0 {
                analytics.track(.gemsEarned(amount: gained, source: "daily_streak"))
            }
            return streak
        }

        func highScoreText() -> String { "Best: \(data.highScore)" }
        func gemBalanceText() -> String { "Gems: \(data.gems)" }
        func multiplierText() -> String { data.multiplierTimeRemaining() != nil ? "Multiplier active" : "Multiplier inactive" }

        func observeProducts(_ update: @escaping () -> Void) {
            productObserver = purchases.observeProducts { [weak self] products in
                self?.cachedProducts = products
                update()
            }
        }

        func displayProducts() -> [DisplayProduct] {
            let products: [PurchaseManaging.StoreProduct]
            if cachedProducts.isEmpty {
                products = PurchaseManager.ProductID.allCases.map { id in
                    PurchaseManaging.StoreProduct(id: id,
                                                   title: id.displayName,
                                                   description: id.marketingDescription,
                                                   price: id.defaultPrice,
                                                   rawPrice: nil,
                                                   storeIdentifier: id.defaultStoreIdentifier)
                }
            } else {
                products = cachedProducts
            }

            let hero = remoteConfig?.heroProduct
            return products.sorted { lhs, rhs in
                if let hero, lhs.id == hero && rhs.id != hero { return true }
                if let hero, rhs.id == hero && lhs.id != hero { return false }
                return lhs.id.sortIndex < rhs.id.sortIndex
            }.map { product in
                let merchandising = remoteConfig?.merchandising(for: product.id)
                let price = merchandising?.priceOverride ?? product.price
                let detail = merchandising?.marketingMessage ?? product.description
                let badge = merchandising?.badge
                let highlight = merchandising?.highlight == true || hero == product.id
                return DisplayProduct(title: product.title, price: price, detail: detail, badge: badge, highlight: highlight)
            }
        }

        func startTapped() {
            sound.play(.gameStart)
        }
    }

    public weak var menuDelegate: MenuSceneDelegate?

    private let viewModel: ViewModel
    private let assets: AssetGenerating

    private var startButton: SKSpriteNode?
    private var restoreButton: SKLabelNode?
    private var productNodes: [SKNode] = []
    private var streakBadge: SKSpriteNode?
    private var gemLabel: SKLabelNode?
    private var highScoreLabel: SKLabelNode?
    private var streakDetailLabel: SKLabelNode?

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
        removeAllChildren()

        addChild(assets.makeBackground(size: CGSize(width: size.width * 2, height: size.height * 2)))
        configureBranding()
        configureButtons()
        layoutProducts()

        let streak = viewModel.registerDailyStreak()
        updateStreakBadge(with: streak)
        updateMetaLabels()
        viewModel.observeProducts { [weak self] in
            self?.layoutProducts()
        }
    }

    private func configureBranding() {
        let logoSize = CGSize(width: min(size.width * 0.6, 320), height: min(size.width * 0.6, 320) * 0.6)
        let logo = assets.makeLogoNode(size: logoSize)
        logo.position = CGPoint(x: 0, y: size.height * 0.25)
        addChild(logo)

        let streak = assets.makeBadgeNode(title: "Daily Streak",
                                          subtitle: "",
                                          size: CGSize(width: min(size.width * 0.55, 260), height: 60),
                                          icon: .streak)
        streak.position = CGPoint(x: 0, y: size.height * 0.05)
        addChild(streak)
        streakBadge = streak
        streakDetailLabel = streak.childNode(withName: "badgeSubtitle") as? SKLabelNode

        let highScore = SKLabelNode(fontNamed: "Orbitron-Bold")
        highScore.fontSize = 20
        highScore.fontColor = .white
        highScore.position = CGPoint(x: 0, y: size.height * 0.38)
        addChild(highScore)
        highScoreLabel = highScore

        let gem = SKLabelNode(fontNamed: "Orbitron-Bold")
        gem.fontSize = 18
        gem.fontColor = GamePalette.cyan
        gem.position = CGPoint(x: 0, y: size.height * 0.32)
        addChild(gem)
        gemLabel = gem
    }

    private func configureButtons() {
        let button = assets.makeButtonNode(text: "Tap to Launch", size: CGSize(width: 240, height: 80), icon: .play)
        button.position = CGPoint(x: 0, y: -size.height * 0.05)
        button.name = "start"
        addChild(button)
        startButton = button

        let restore = SKLabelNode(fontNamed: "SFProRounded-Regular")
        restore.text = "Restore Purchases"
        restore.fontSize = 16
        restore.fontColor = UIColor.white.withAlphaComponent(0.75)
        restore.position = CGPoint(x: 0, y: -size.height * 0.42)
        addChild(restore)
        restoreButton = restore
    }

    private func layoutProducts() {
        productNodes.forEach { $0.removeFromParent() }
        productNodes.removeAll()

        let products = viewModel.displayProducts()
        guard !products.isEmpty else { return }
        let spacing: CGFloat = 16
        let totalHeight = CGFloat(products.count) * 70 + CGFloat(products.count - 1) * spacing
        var currentY = -size.height * 0.18
        currentY += totalHeight / 2

        for product in products {
            let subtitle = "\(product.price) • \(product.detail)"
            let node = assets.makeMonetizationButton(title: product.title, subtitle: subtitle, icon: "💠")
            node.position = CGPoint(x: 0, y: currentY)
            node.name = product.title
            node.alpha = product.highlight ? 1.0 : 0.85
            if let badge = product.badge {
                let badgeLabel = SKLabelNode(fontNamed: "Orbitron-Bold")
                badgeLabel.text = badge
                badgeLabel.fontSize = 12
                badgeLabel.fontColor = .white
                badgeLabel.position = CGPoint(x: node.size.width * 0.35, y: node.size.height * 0.25)
                badgeLabel.zPosition = 2
                node.addChild(badgeLabel)
            }
            addChild(node)
            productNodes.append(node)
            currentY -= (70 + spacing)
        }
    }

    private func updateStreakBadge(with streak: DailyStreak) {
        let title = "Daily Streak: \(streak.streakDays)d"
        let subtitle = String(format: "+%.0f gems • x%.1f boost", streak.reward, streak.multiplierBonus)
        (streakBadge?.childNode(withName: "badgeTitle") as? SKLabelNode)?.text = title
        streakDetailLabel?.text = subtitle
        streakBadge?.alpha = streak.isMultiplierActive ? 1.0 : 0.7
    }

    private func updateMetaLabels() {
        highScoreLabel?.text = viewModel.highScoreText()
        gemLabel?.text = viewModel.gemBalanceText()
    }

    // MARK: - Touch Handling

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        if let button = startButton, button.contains(location) {
            button.setPressed(true)
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        startButton?.setPressed(false)

        if let button = startButton, button.contains(location) {
            viewModel.startTapped()
            menuDelegate?.menuSceneDidStartGame(self)
            return
        }

        if let restore = restoreButton, restore.contains(location) {
            menuDelegate?.menuSceneDidRequestRestore(self)
            return
        }

        if let product = productNodes.first(where: { $0.contains(location) }) {
            menuDelegate?.menuScene(self, didSelectProduct: product.name ?? "")
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        startButton?.setPressed(false)
    }
}

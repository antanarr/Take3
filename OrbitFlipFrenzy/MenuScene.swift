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
        struct IAPProduct {
            let id: PurchaseManaging.ProductID
            let title: String
            let price: String
            let detail: String
            let badge: String?
            let highlight: Bool
        }

        struct CosmeticOption {
            let id: String
            let name: String
            let description: String
            let cost: Int
        }

        enum CosmeticResult {
            case equipped(name: String)
            case purchased(name: String, cost: Int)
            case insufficient(required: Int, balance: Int)
            case locked(message: String)
        }

        private let assets: AssetGenerating
        private let data: GameData
        private let sound: SoundPlaying
        private let purchases: PurchaseManaging
        private let analytics: AnalyticsTracking
        private let remoteConfig: RemoteConfigProviding?
        private var cachedProducts: [PurchaseManaging.StoreProduct] = []

        private let cosmetics: [CosmeticOption] = [
            CosmeticOption(id: PlayerEntitlements.defaultSkinIdentifier,
                            name: "Classic Pod",
                            description: "Default chassis with trail fx.",
                            cost: 0),
            CosmeticOption(id: GameConstants.starterPackSkinIdentifier,
                            name: "Nova Pod",
                            description: "Starter Pack exclusive skin.",
                            cost: 0),
            CosmeticOption(id: "solar_flare",
                            name: "Solar Flare",
                            description: "Burn with orange photon trails.",
                            cost: 300),
            CosmeticOption(id: "lunar_shadow",
                            name: "Lunar Shadow",
                            description: "Deep violet tracer for night runs.",
                            cost: 450)
        ]

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

        func registerDailyStreak() -> DailyStreak {
            let previous = data.gems
            let streak = data.registerDailyPlay()
            let gained = data.gems - previous
            if gained > 0 {
                analytics.track(.gemsEarned(amount: gained, source: "daily_streak"))
            }
            return streak
        }

        var highScoreText: String { "Best: \(data.highScore)" }

        func observeProducts(_ handler: @escaping ([PurchaseManaging.StoreProduct]) -> Void) -> UUID {
            purchases.observeProducts { [weak self] products in
                self?.cachedProducts = products
                handler(products)
            }
        }

        func removeObserver(_ token: UUID) {
            purchases.removeObserver(token)
        }

        func observeConfigUpdates(_ handler: @escaping () -> Void) -> UUID? {
            remoteConfig?.addObserver(handler)
        }

        func removeConfigObserver(_ token: UUID) {
            remoteConfig?.removeObserver(token)
        }

        var iapProducts: [IAPProduct] {
            let storeProducts: [PurchaseManaging.StoreProduct]
            if cachedProducts.isEmpty {
                storeProducts = PurchaseManager.ProductID.allCases.map { id in
                    let merchandising = remoteConfig?.merchandising(for: id)
                    return PurchaseManaging.StoreProduct(id: id,
                                                         title: id.displayName,
                                                         description: merchandising?.marketingMessage ?? id.marketingDescription,
                                                         price: merchandising?.priceOverride ?? id.defaultPrice,
                                                         rawPrice: nil,
                                                         storeIdentifier: remoteConfig?.storeIdentifier(for: id) ?? id.defaultStoreIdentifier)
                }
            } else {
                storeProducts = cachedProducts
            }
            let starterStatus = starterPackStatus()
            let hero = remoteConfig?.heroProduct
            var decorated = storeProducts.map { product -> IAPProduct in
                let merchandising = remoteConfig?.merchandising(for: product.id)
                let highlight = (product.id == .starterPack && starterStatus.highlight) || merchandising?.highlight == true || (hero == product.id)
                let detail: String
                if product.id == .starterPack {
                    if starterStatus.highlight {
                        detail = starterStatus.text
                    } else if let message = merchandising?.marketingMessage {
                        detail = message
                    } else {
                        detail = product.description
                    }
                } else {
                    detail = merchandising?.marketingMessage ?? product.description
                }
                let price = merchandising?.priceOverride ?? product.price
                return IAPProduct(id: product.id,
                                  title: product.title,
                                  price: price,
                                  detail: detail,
                                  badge: merchandising?.badge,
                                  highlight: highlight)
            }
            if let hero {
                decorated.sort { lhs, rhs in
                    if lhs.id == hero && rhs.id != hero { return true }
                    if rhs.id == hero && lhs.id != hero { return false }
                    return lhs.id.sortIndex < rhs.id.sortIndex
                }
            } else {
                decorated.sort { $0.id.sortIndex < $1.id.sortIndex }
            }
            return decorated
        }

        func createButton(title: String, size: CGSize) -> SKSpriteNode {
            assets.makeButtonNode(text: title, size: size)
        }

        func playStartSound() {
            sound.play(.gameStart)
        }

        func currentGemBalance() -> Int { data.gems }

        func multiplierCountdownText() -> String {
            guard let remaining = data.multiplierTimeRemaining(), remaining > 0 else {
                return "Multiplier inactive"
            }
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            if hours > 0 {
                return String(format: "Multiplier active %02dh %02dm", hours, minutes)
            }
            let seconds = Int(remaining) % 60
            return String(format: "Multiplier active %02dm %02ds", minutes, seconds)
        }

        func starterPackStatus() -> (text: String, highlight: Bool) {
            if data.shouldOfferStarterPack() {
                return ("Starter Pack ready! +\(GameConstants.starterPackGemGrant) gems", true)
            }
            let remaining = data.starterPackCooldownRemaining()
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            return (String(format: "Starter Pack unlocks in %02dh %02dm", hours, minutes), false)
        }

        func currentCosmeticID() -> String {
            data.equippedCosmetic
        }

        func option(after identifier: String) -> CosmeticOption {
            guard let index = cosmetics.firstIndex(where: { $0.id == identifier }) else {
                return cosmetics.first ?? CosmeticOption(id: PlayerEntitlements.defaultSkinIdentifier,
                                                         name: "Classic Pod",
                                                         description: "Default chassis.",
                                                         cost: 0)
            }
            let nextIndex = (index + 1) % cosmetics.count
            return cosmetics[nextIndex]
        }

        func option(for identifier: String) -> CosmeticOption? {
            cosmetics.first { $0.id == identifier }
        }

        func cosmeticResult(for option: CosmeticOption) -> CosmeticResult {
            if data.hasCosmetic(option.id) {
                data.equipCosmetic(option.id)
                return .equipped(name: option.name)
            }
            if option.cost == 0 {
                return .locked(message: option.description)
            }
            guard data.spendGems(option.cost) else {
                return .insufficient(required: option.cost, balance: data.gems)
            }
            analytics.track(.gemsSpent(amount: option.cost, reason: "cosmetic_\(option.id)"))
            data.unlockCosmetic(option.id)
            data.equipCosmetic(option.id)
            return .purchased(name: option.name, cost: option.cost)
        }

        func cosmeticDescription(for option: CosmeticOption) -> String {
            if data.hasCosmetic(option.id) {
                return option.description
            }
            if option.cost > 0 {
                return "Costs \(option.cost) gems"
            }
            return option.description
        }
    }

    public weak var menuDelegate: MenuSceneDelegate?

    private let viewModel: ViewModel
    private let assets: AssetGenerating
    private var startButton: SKSpriteNode?
    private var streakLabel: SKLabelNode?
    private var multiplierCountdownLabel: SKLabelNode?
    private var gemBalanceLabel: SKLabelNode?
    private var starterPackStatusLabel: SKLabelNode?
    private var statusLabel: SKLabelNode?
    private var cosmeticNode: SKShapeNode?
    private var cosmeticTitleLabel: SKLabelNode?
    private var cosmeticDetailLabel: SKLabelNode?
    private struct ProductNodeBundle {
        var title: SKLabelNode
        var detail: SKLabelNode
        var badge: SKLabelNode?
    }

    private var productNodes: [PurchaseManager.ProductID: ProductNodeBundle] = [:]
    private var productObserverToken: UUID?
    private var remoteConfigObserverToken: UUID?
    private var currentCosmeticOption: ViewModel.CosmeticOption?
    private var lastGemBalance: Int = 0
    private var statusMessageTimeRemaining: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var productsAnchorY: CGFloat = 0
    private var countdownAccumulator: TimeInterval = 0
    private var restoreButton: SKSpriteNode?

    public init(size: CGSize, viewModel: ViewModel, assets: AssetGenerating) {
        self.viewModel = viewModel
        self.assets = assets
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let token = productObserverToken {
            viewModel.removeObserver(token)
        }
        if let token = remoteConfigObserverToken {
            viewModel.removeConfigObserver(token)
        }
    }

    public override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = GamePalette.deepNavy

        let background = assets.makeBackground(size: view.bounds.size)
        addChild(background)

        let heroWidth = min(view.bounds.width * 0.7, 320)
        let logo = assets.makeLogoNode(size: CGSize(width: heroWidth, height: heroWidth * 0.42))
        logo.position = CGPoint(x: 0, y: view.bounds.height * 0.3)
        logo.alpha = 0
        logo.run(SKAction.fadeIn(withDuration: 0.8))
        addChild(logo)

        let iconSprite = SKSpriteNode(texture: SKTexture(image: assets.makeAppIconImage(size: CGSize(width: 160, height: 160))))
        iconSprite.size = CGSize(width: 110, height: 110)
        iconSprite.position = CGPoint(x: -heroWidth * 0.58, y: logo.position.y)
        iconSprite.alpha = 0
        iconSprite.run(SKAction.sequence([SKAction.wait(forDuration: 0.2), SKAction.fadeIn(withDuration: 0.6)]))
        addChild(iconSprite)

        let tagline = SKLabelNode(text: "Flip faster. Dodge harder. Own the orbit.")
        tagline.fontName = "SFProRounded-Bold"
        tagline.fontSize = 18
        tagline.fontColor = GamePalette.cyan
        tagline.position = CGPoint(x: 0, y: logo.position.y - heroWidth * 0.36)
        tagline.alpha = 0
        tagline.run(SKAction.sequence([SKAction.wait(forDuration: 0.35), SKAction.fadeIn(withDuration: 0.7)]))
        addChild(tagline)

        let start = viewModel.createButton(title: "Tap to Launch", size: CGSize(width: 240, height: 80))
        start.position = CGPoint(x: 0, y: tagline.position.y - 90)
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
        streakNode.position = CGPoint(x: 0, y: start.position.y - 120)
        addChild(streakNode)
        streakLabel = streakNode

        let multiplier = SKLabelNode(text: viewModel.multiplierCountdownText())
        multiplier.fontName = "SFProRounded-Regular"
        multiplier.fontColor = UIColor.white.withAlphaComponent(0.75)
        multiplier.fontSize = 14
        multiplier.position = CGPoint(x: 0, y: streakNode.position.y - 34)
        addChild(multiplier)
        multiplierCountdownLabel = multiplier

        let bestLabel = SKLabelNode(text: viewModel.highScoreText)
        bestLabel.fontName = "Orbitron-Bold"
        bestLabel.fontSize = 18
        bestLabel.fontColor = GamePalette.solarGold
        bestLabel.position = CGPoint(x: 0, y: multiplier.position.y - 34)
        addChild(bestLabel)

        let gems = SKLabelNode(text: "Gems: \(viewModel.currentGemBalance())")
        gems.fontName = "Orbitron-Bold"
        gems.fontSize = 18
        gems.fontColor = GamePalette.cyan
        gems.horizontalAlignmentMode = .right
        gems.position = CGPoint(x: view.bounds.width * 0.45, y: logo.position.y + heroWidth * 0.32)
        addChild(gems)
        gemBalanceLabel = gems
        lastGemBalance = viewModel.currentGemBalance()

        let starterStatus = viewModel.starterPackStatus()
        let starterLabel = SKLabelNode(text: starterStatus.text)
        starterLabel.fontName = "SFProRounded-Bold"
        starterLabel.fontSize = 16
        starterLabel.fontColor = starterStatus.highlight ? GamePalette.solarGold : UIColor.white.withAlphaComponent(0.7)
        starterLabel.position = CGPoint(x: 0, y: bestLabel.position.y - 46)
        addChild(starterLabel)
        starterPackStatusLabel = starterLabel

        productsAnchorY = starterLabel.position.y - 60
        layoutProducts(around: productsAnchorY)

        let cosmetic = SKShapeNode(rectOf: CGSize(width: 280, height: 84), cornerRadius: 20)
        cosmetic.fillColor = GamePalette.neonMagenta.withAlphaComponent(0.2)
        cosmetic.strokeColor = GamePalette.neonMagenta
        cosmetic.lineWidth = 2
        cosmetic.position = CGPoint(x: 0, y: productsAnchorY - 140)
        cosmetic.name = "cosmetic_button"
        addChild(cosmetic)
        cosmeticNode = cosmetic

        let title = SKLabelNode(fontNamed: "SFProRounded-Bold")
        title.fontSize = 18
        title.fontColor = GamePalette.neonMagenta
        title.position = CGPoint(x: 0, y: 14)
        title.name = "cosmetic_title"
        cosmetic.addChild(title)
        cosmeticTitleLabel = title

        let detail = SKLabelNode(fontNamed: "SFProRounded-Regular")
        detail.fontSize = 14
        detail.fontColor = UIColor.white.withAlphaComponent(0.8)
        detail.position = CGPoint(x: 0, y: -12)
        detail.name = "cosmetic_detail"
        cosmetic.addChild(detail)
        cosmeticDetailLabel = detail

        currentCosmeticOption = viewModel.option(for: viewModel.currentCosmeticID())
        updateCosmeticDisplay()

        let status = SKLabelNode(fontNamed: "SFProRounded-Bold")
        status.fontSize = 16
        status.fontColor = UIColor.white
        status.alpha = 0
        status.position = CGPoint(x: 0, y: -view.bounds.height * 0.35)
        addChild(status)
        statusLabel = status

        let restore = viewModel.createButton(title: "Restore Purchases", size: CGSize(width: 220, height: 60))
        restore.position = CGPoint(x: 0, y: status.position.y + 70)
        restore.name = "restore"
        addChild(restore)
        restoreButton = restore

        productObserverToken = viewModel.observeProducts { [weak self] _ in
            guard let self else { return }
            self.layoutProducts(around: self.productsAnchorY)
            self.updateProductHighlight()
        }
        remoteConfigObserverToken = viewModel.observeConfigUpdates { [weak self] in
            guard let self else { return }
            self.layoutProducts(around: self.productsAnchorY)
            self.updateProductHighlight()
        }
    }

    private func layoutProducts(around y: CGFloat) {
        productNodes.values.forEach { nodes in
            nodes.title.removeFromParent()
            nodes.detail.removeFromParent()
            nodes.badge?.removeFromParent()
        }
        productNodes.removeAll()

        let products = viewModel.iapProducts
        let spacing: CGFloat = 46
        for (index, product) in products.enumerated() {
            let label = SKLabelNode(text: "• \(product.title) — \(product.price)")
            label.fontName = "SFProRounded-Bold"
            label.fontSize = 18
            label.fontColor = product.highlight ? GamePalette.solarGold : GamePalette.cyan
            label.position = CGPoint(x: 0, y: y - CGFloat(index) * spacing)
            label.name = "product_\(product.id.rawValue)"
            label.userData = ["product": product.id.displayName]
            addChild(label)

            let detail = SKLabelNode(text: product.detail)
            detail.fontName = "SFProRounded-Regular"
            detail.fontSize = 14
            detail.fontColor = product.highlight ? GamePalette.solarGold : UIColor.white.withAlphaComponent(0.7)
            detail.position = CGPoint(x: 0, y: label.position.y - 18)
            detail.name = "product_detail_\(product.id.rawValue)"
            detail.userData = ["product": product.id.displayName]
            addChild(detail)

            var badgeNode: SKLabelNode?
            if let badge = product.badge {
                let badgeLabel = SKLabelNode(fontNamed: "SFProRounded-Bold")
                badgeLabel.fontSize = 12
                badgeLabel.fontColor = GamePalette.neonMagenta
                badgeLabel.text = badge.uppercased()
                badgeLabel.position = CGPoint(x: 0, y: detail.position.y - 18)
                badgeLabel.name = "product_badge_\(product.id.rawValue)"
                badgeLabel.userData = ["product": product.id.displayName]
                addChild(badgeLabel)
                badgeNode = badgeLabel
            }

            productNodes[product.id] = ProductNodeBundle(title: label, detail: detail, badge: badgeNode)
        }
    }

    private func updateCosmeticDisplay() {
        guard let option = currentCosmeticOption ?? viewModel.option(for: viewModel.currentCosmeticID()) else { return }
        cosmeticTitleLabel?.text = "Current Skin: \(option.name)"
        cosmeticDetailLabel?.text = viewModel.cosmeticDescription(for: option)
    }

    private func handleCosmeticTap() {
        let currentID = currentCosmeticOption?.id ?? viewModel.currentCosmeticID()
        let nextOption = viewModel.option(after: currentID)
        currentCosmeticOption = nextOption
        let result = viewModel.cosmeticResult(for: nextOption)
        switch result {
        case .insufficient, .locked:
            break
        default:
            currentCosmeticOption = viewModel.option(for: viewModel.currentCosmeticID())
        }
        updateCosmeticDisplay()
        updateGemBalanceIfNeeded()
        switch result {
        case let .equipped(name):
            showStatusMessage("Equipped \(name)!", color: GamePalette.cyan)
        case let .purchased(name, cost):
            showStatusMessage("Purchased \(name) for \(cost) gems!", color: GamePalette.solarGold)
        case let .insufficient(required, balance):
            showStatusMessage("Need \(required) gems (have \(balance)).", color: UIColor.systemRed)
        case let .locked(message):
            showStatusMessage(message, color: GamePalette.solarGold)
        }
    }

    private func updateStarterPackStatus() {
        guard let label = starterPackStatusLabel else { return }
        let status = viewModel.starterPackStatus()
        label.text = status.text
        label.fontColor = status.highlight ? GamePalette.solarGold : UIColor.white.withAlphaComponent(0.7)
    }

    private func updateProductHighlight() {
        let products = viewModel.iapProducts
        for product in products {
            guard var bundle = productNodes[product.id] else { continue }
            bundle.title.text = "• \(product.title) — \(product.price)"
            bundle.title.fontColor = product.highlight ? GamePalette.solarGold : GamePalette.cyan
            bundle.detail.text = product.detail
            bundle.detail.fontColor = product.highlight ? GamePalette.solarGold : UIColor.white.withAlphaComponent(0.7)
            if let badgeText = product.badge {
                if let badgeNode = bundle.badge {
                    badgeNode.text = badgeText.uppercased()
                    badgeNode.isHidden = false
                    badgeNode.position = CGPoint(x: 0, y: bundle.detail.position.y - 18)
                } else {
                    let badgeNode = SKLabelNode(fontNamed: "SFProRounded-Bold")
                    badgeNode.fontSize = 12
                    badgeNode.fontColor = GamePalette.neonMagenta
                    badgeNode.text = badgeText.uppercased()
                    badgeNode.position = CGPoint(x: 0, y: bundle.detail.position.y - 18)
                    badgeNode.name = "product_badge_\(product.id.rawValue)"
                    badgeNode.userData = ["product": product.id.displayName]
                    addChild(badgeNode)
                    bundle.badge = badgeNode
                }
            } else {
                bundle.badge?.isHidden = true
            }
            productNodes[product.id] = bundle
        }
    }

    private func updateGemBalanceIfNeeded() {
        let balance = viewModel.currentGemBalance()
        if balance != lastGemBalance {
            lastGemBalance = balance
            gemBalanceLabel?.text = "Gems: \(balance)"
        }
    }

    private func showStatusMessage(_ text: String, color: UIColor) {
        guard let label = statusLabel else { return }
        label.removeAllActions()
        label.text = text
        label.fontColor = color
        label.alpha = 1.0
        statusMessageTimeRemaining = 2.5
    }

    public override func update(_ currentTime: TimeInterval) {
        let delta: TimeInterval
        if lastUpdateTime == 0 {
            delta = 0
        } else {
            delta = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime
        countdownAccumulator += delta
        if countdownAccumulator >= 1.0 {
            multiplierCountdownLabel?.text = viewModel.multiplierCountdownText()
            updateStarterPackStatus()
            updateProductHighlight()
            countdownAccumulator = 0
        }
        updateGemBalanceIfNeeded()
        if statusMessageTimeRemaining > 0 {
            statusMessageTimeRemaining = max(0, statusMessageTimeRemaining - delta)
        }
        if statusMessageTimeRemaining == 0, let label = statusLabel, label.alpha > 0 {
            label.run(SKAction.fadeOut(withDuration: 0.25))
            statusMessageTimeRemaining = -1
        }
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        let nodes = nodes(at: location)
        if let start = startButton, nodes.contains(start) || nodes.contains(where: { $0.name == "label" && $0.parent == start }) {
            startButton?.setPressed(true)
        } else if let cosmetic = cosmeticNode, nodes.contains(cosmetic) || nodes.contains(where: { $0.parent == cosmetic }) {
            cosmetic.run(SKAction.scale(to: 0.96, duration: 0.1))
        } else if let restore = restoreButton, nodes.contains(restore) || nodes.contains(where: { $0.name == "label" && $0.parent == restore }) {
            restore.run(SKAction.scale(to: 0.96, duration: 0.1))
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        startButton?.setPressed(false)
        cosmeticNode?.run(SKAction.scale(to: 1.0, duration: 0.1))
        restoreButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
        let nodes = nodes(at: location)
        if let start = startButton, nodes.contains(start) || nodes.contains(where: { $0.name == "label" && $0.parent == start }) {
            viewModel.playStartSound()
            menuDelegate?.menuSceneDidStartGame(self)
            return
        }
        if let cosmetic = cosmeticNode, nodes.contains(cosmetic) || nodes.contains(where: { $0.parent == cosmetic }) {
            handleCosmeticTap()
            return
        }
        if let restore = restoreButton, nodes.contains(restore) || nodes.contains(where: { $0.name == "label" && $0.parent == restore }) {
            showStatusMessage("Restoring purchases...", color: GamePalette.cyan)
            menuDelegate?.menuSceneDidRequestRestore(self)
            return
        }
        if let label = nodes.compactMap({ $0 as? SKLabelNode }).first,
           let productTitle = label.userData?["product"] as? String {
            menuDelegate?.menuScene(self, didSelectProduct: productTitle)
        }
    }
}

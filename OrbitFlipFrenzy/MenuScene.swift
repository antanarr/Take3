import Foundation
import SpriteKit
import UIKit

public protocol MenuSceneDelegate: AnyObject {
    func menuSceneDidStartGame(_ scene: MenuScene)
    func menuScene(_ scene: MenuScene, didSelectProduct name: String)
    func menuSceneDidRequestRestore(_ scene: MenuScene)
}

public final class MenuScene: SKScene {

    private enum LegalDocument {
        case terms
        case privacy

        var title: String {
            switch self {
            case .terms: return "Terms of Use"
            case .privacy: return "Privacy Policy"
            }
        }

        var sections: [(title: String, body: String)] {
            switch self {
            case .terms:
                return [
                    ("Overview", "Orbital Flip Frenzy is published by HyperNova Labs. Playing the game means you accept these Terms and confirm you are at least 13 years old or have guardian permission."),
                    ("Player Responsibilities", "Use the app only for personal entertainment. Do not exploit bugs, harass other players, or attempt to reverse engineer or redistribute the software."),
                    ("Purchases & Ads", "All in-app purchases are optional. Virtual currency and items have no real-world value and are non-refundable except where required by law. Rewarded ads are simulated and never collect personal data."),
                    ("Health & Contact", "Play safely and stop if you feel discomfort, dizziness, or eye strain. For support email support@orbitflipfrenzy.fake. These Terms are governed by the laws of your local jurisdiction.")
                ]
            case .privacy:
                return [
                    ("Data We Collect", "The game stores high scores, achievements, and remote configuration locally on your device. No personal identifiers are transmitted."),
                    ("How Data Is Used", "Anonymous gameplay metrics are used to tune difficulty, power-up balance, and monetisation pacing. Remote config tokens secure analytics batching."),
                    ("Your Choices", "You can reset saved progress at any time from the settings menu to delete stored data. Uninstalling the app removes all locally stored information."),
                    ("Contact & Updates", "For privacy requests email privacy@orbitflipfrenzy.fake. We will notify players in-app before making material changes to this policy.")
                ]
            }
        }
    }

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

        func shouldShowCurrency() -> Bool {
            let state = data.onboardingState
            return state.hasSeenCurrency || state.isComplete || data.gems > 0
        }

        func shouldShowShopToggle() -> Bool {
            let state = data.onboardingState
            return state.hasSeenPremiumStore || state.isComplete || data.gems >= GameConstants.shieldPowerupGemCost
        }

        func shouldShowStreakBadge() -> Bool {
            let state = data.onboardingState
            return state.isComplete || data.dailyStreak.streakDays > 1
        }

        func markCurrencySeenIfNeeded() {
            var state = data.onboardingState
            if !state.hasSeenCurrency {
                state.hasSeenCurrency = true
                data.onboardingState = state
            }
        }

        func markPremiumStoreSeenIfNeeded() {
            var state = data.onboardingState
            if !state.hasSeenPremiumStore {
                state.hasSeenPremiumStore = true
                data.onboardingState = state
            }
        }

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
    private var shopToggleButton: SKSpriteNode?
    private var shopVisible = false
    private var currentStreak: DailyStreak?
    private var legalButton: SKSpriteNode?
    private var privacyButton: SKSpriteNode?
    private var legalOverlay: SKSpriteNode?
    private var legalPanel: SKShapeNode?
    private var legalCloseButton: SKSpriteNode?

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
        updateStreakBadge(with: streak, animated: false)
        updateMetaLabels()
        updateShopVisibility(animated: false)
        viewModel.observeProducts { [weak self] in
            self?.layoutProducts()
            self?.updateShopVisibility(animated: false)
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
        streakBadge?.isHidden = true
        streakBadge?.alpha = 0.0

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
        gemLabel?.isHidden = true
        gemLabel?.alpha = 0.0
    }

    private func configureButtons() {
        let button = assets.makeButtonNode(text: "Tap to Launch", size: CGSize(width: 240, height: 80), icon: .play)
        button.position = CGPoint(x: 0, y: -size.height * 0.05)
        button.name = "start"
        addChild(button)
        startButton = button

        let shopToggle = assets.makeButtonNode(text: "Shop", size: CGSize(width: 180, height: 60), icon: .gems)
        shopToggle.position = CGPoint(x: 0, y: -size.height * 0.22)
        shopToggle.name = "shop_toggle"
        addChild(shopToggle)
        shopToggleButton = shopToggle

        let restore = SKLabelNode(fontNamed: "SFProRounded-Regular")
        restore.text = "Restore Purchases"
        restore.fontSize = 16
        restore.fontColor = UIColor.white.withAlphaComponent(0.75)
        restore.position = CGPoint(x: 0, y: -size.height * 0.42)
        restore.alpha = 0.0
        restore.isHidden = true
        addChild(restore)
        restoreButton = restore

        let legal = assets.makeButtonNode(text: "Terms", size: CGSize(width: 150, height: 52), icon: .info)
        legal.position = CGPoint(x: -size.width * 0.28, y: -size.height * 0.46)
        legal.alpha = 0.9
        legal.name = "terms"
        addChild(legal)
        legalButton = legal

        let privacy = assets.makeButtonNode(text: "Privacy", size: CGSize(width: 150, height: 52), icon: .info)
        privacy.position = CGPoint(x: size.width * 0.28, y: -size.height * 0.46)
        privacy.alpha = 0.9
        privacy.name = "privacy"
        addChild(privacy)
        privacyButton = privacy

        updateShopToggleTitle()
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
            let targetAlpha: CGFloat = product.highlight ? 1.0 : 0.85
            node.alpha = shopVisible ? targetAlpha : 0.0
            let metadata = node.userData ?? NSMutableDictionary()
            metadata["targetAlpha"] = targetAlpha
            node.userData = metadata
            node.isHidden = !shopVisible
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

    private func updateStreakBadge(with streak: DailyStreak, animated: Bool = true) {
        currentStreak = streak
        let title = "Daily Streak: \(streak.streakDays)d"
        let subtitle = String(format: "+%.0f gems • x%.1f boost", streak.reward, streak.multiplierBonus)
        (streakBadge?.childNode(withName: "badgeTitle") as? SKLabelNode)?.text = title
        streakDetailLabel?.text = subtitle
        let visible = shopVisible && viewModel.shouldShowStreakBadge()
        let targetAlpha: CGFloat = streak.isMultiplierActive ? 1.0 : 0.7
        applyVisibility(to: streakBadge, visible: visible, alpha: targetAlpha, animated: animated)
    }

    private func updateMetaLabels() {
        highScoreLabel?.text = viewModel.highScoreText()
        gemLabel?.text = viewModel.gemBalanceText()
        updateGemLabelVisibility(animated: false)
    }

    private func updateGemLabelVisibility(animated: Bool) {
        guard let label = gemLabel else { return }
        let shouldShow = viewModel.shouldShowCurrency()
        if shouldShow { viewModel.markCurrencySeenIfNeeded() }
        applyVisibility(to: label, visible: shouldShow, alpha: 1.0, animated: animated)
    }

    private func updateShopVisibility(animated: Bool) {
        let canShowShop = viewModel.shouldShowShopToggle()
        if !canShowShop { shopVisible = false }
        shopToggleButton?.isHidden = !canShowShop
        updateShopToggleTitle()

        let duration: TimeInterval = animated ? 0.25 : 0.0
        for case let node as SKSpriteNode in productNodes {
            let targetAlpha = (node.userData?["targetAlpha"] as? CGFloat) ?? 1.0
            let finalAlpha = shopVisible ? targetAlpha : 0.0
            if animated {
                node.removeAllActions()
                if shopVisible {
                    node.isHidden = false
                    node.run(SKAction.fadeAlpha(to: finalAlpha, duration: duration))
                } else {
                    node.run(SKAction.sequence([
                        SKAction.fadeAlpha(to: 0.0, duration: duration),
                        SKAction.run { node.isHidden = true }
                    ]))
                }
            } else {
                node.alpha = finalAlpha
                node.isHidden = !shopVisible
            }
        }

        if let restore = restoreButton {
            let visible = shopVisible && canShowShop
            if animated {
                restore.removeAllActions()
                if visible {
                    restore.isHidden = false
                    restore.run(SKAction.fadeAlpha(to: 0.8, duration: duration))
                } else {
                    restore.run(SKAction.sequence([
                        SKAction.fadeOut(withDuration: duration),
                        SKAction.run { restore.isHidden = true }
                    ]))
                }
            } else {
                restore.alpha = visible ? 0.8 : 0.0
                restore.isHidden = !visible
            }
        }

        if let streak = currentStreak {
            updateStreakBadge(with: streak, animated: animated)
        } else {
            let shouldShowStreak = viewModel.shouldShowStreakBadge()
            let streakVisible = shopVisible && shouldShowStreak
            applyVisibility(to: streakBadge, visible: streakVisible, alpha: 1.0, animated: animated)
        }
        updateGemLabelVisibility(animated: animated)
    }

    private func updateShopToggleTitle() {
        guard let button = shopToggleButton,
              let label = button.childNode(withName: "label") as? SKLabelNode else { return }
        label.text = shopVisible ? "Close Shop" : "Shop"
        button.alpha = button.isHidden ? 0.0 : 1.0
    }

    private func toggleShopVisibility() {
        guard viewModel.shouldShowShopToggle() else { return }
        if !shopVisible {
            viewModel.markPremiumStoreSeenIfNeeded()
        }
        shopVisible.toggle()
        updateShopVisibility(animated: true)
    }

    private func applyVisibility(to node: SKNode?, visible: Bool, alpha: CGFloat, animated: Bool) {
        guard let node else { return }
        if animated {
            node.removeAllActions()
            if visible {
                node.isHidden = false
                node.run(SKAction.fadeAlpha(to: alpha, duration: 0.25))
            } else {
                node.run(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.0, duration: 0.2),
                    SKAction.run { node.isHidden = true }
                ]))
            }
        } else {
            node.alpha = visible ? alpha : 0.0
            node.isHidden = !visible
        }
    }

    private func presentLegalDocument(_ document: LegalDocument) {
        dismissLegalOverlay(animated: false)

        let overlay = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.6), size: size)
        overlay.zPosition = 50
        overlay.position = .zero
        overlay.alpha = 0.0
        addChild(overlay)
        overlay.run(SKAction.fadeAlpha(to: 1.0, duration: 0.25))
        legalOverlay = overlay

        let panelSize = CGSize(width: min(size.width * 0.85, 340), height: min(size.height * 0.72, 520))
        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: 28)
        panel.fillColor = GamePalette.royalBlue.withAlphaComponent(0.95)
        panel.strokeColor = GamePalette.cyan.withAlphaComponent(0.8)
        panel.lineWidth = 4
        panel.position = .zero
        panel.zPosition = 1
        panel.name = "legal_panel"
        overlay.addChild(panel)
        legalPanel = panel

        let titleLabel = SKLabelNode(fontNamed: "Orbitron-Bold")
        titleLabel.text = document.title
        titleLabel.fontSize = 26
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: panelSize.height * 0.38)
        titleLabel.zPosition = 2
        panel.addChild(titleLabel)

        var currentY = panelSize.height * 0.28
        for section in document.sections {
            let heading = SKLabelNode(fontNamed: "Orbitron-Bold")
            heading.text = section.title
            heading.fontSize = 16
            heading.fontColor = GamePalette.solarGold
            heading.horizontalAlignmentMode = .center
            heading.position = CGPoint(x: 0, y: currentY)
            heading.zPosition = 2
            panel.addChild(heading)
            currentY -= heading.fontSize * 1.4

            let bodyLines = wrapText(section.body, maxCharacters: 42)
            for line in bodyLines {
                let body = SKLabelNode(fontNamed: "SFProRounded-Regular")
                body.text = line
                body.fontSize = 13
                body.fontColor = UIColor.white.withAlphaComponent(0.9)
                body.horizontalAlignmentMode = .center
                body.position = CGPoint(x: 0, y: currentY)
                body.zPosition = 2
                panel.addChild(body)
                currentY -= body.fontSize * 1.45
            }

            currentY -= 8
        }

        let close = assets.makeButtonNode(text: "Close", size: CGSize(width: 160, height: 54), icon: .alert)
        close.position = CGPoint(x: 0, y: -panelSize.height * 0.42)
        close.alpha = 0.95
        close.zPosition = 2
        overlay.addChild(close)
        legalCloseButton = close
    }

    private func dismissLegalOverlay(animated: Bool = true) {
        guard let overlay = legalOverlay else { return }
        legalCloseButton?.setPressed(false)
        let cleanup = { [weak self] in
            overlay.removeFromParent()
            self?.legalOverlay = nil
            self?.legalPanel = nil
            self?.legalCloseButton = nil
        }
        if animated {
            overlay.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.2), SKAction.run(cleanup)]))
        } else {
            overlay.removeAllActions()
            cleanup()
        }
    }

    private func wrapText(_ text: String, maxCharacters: Int) -> [String] {
        let words = text.split(separator: " ")
        guard !words.isEmpty else { return [] }
        var lines: [String] = []
        var currentLine = ""
        for word in words {
            if currentLine.isEmpty {
                currentLine = String(word)
            } else if (currentLine.count + word.count + 1) <= maxCharacters {
                currentLine += " " + word
            } else {
                lines.append(currentLine)
                currentLine = String(word)
            }
        }
        if !currentLine.isEmpty { lines.append(currentLine) }
        return lines
    }

    // MARK: - Touch Handling

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        if let overlay = legalOverlay, let close = legalCloseButton {
            let overlayPoint = convert(location, to: overlay)
            if close.contains(overlayPoint) {
                close.setPressed(true)
            }
            return
        }
        interactiveButton(at: location)?.setPressed(true)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        if let overlay = legalOverlay {
            let point = convert(location, to: overlay)
            if let close = legalCloseButton, close.contains(point) {
                close.setPressed(false)
                dismissLegalOverlay()
            } else if let panel = legalPanel, !panel.contains(point) {
                dismissLegalOverlay()
            } else {
                legalCloseButton?.setPressed(false)
            }
            return
        }

        [startButton, shopToggleButton, legalButton, privacyButton].forEach { $0?.setPressed(false) }
        productNodes.compactMap { $0 as? SKSpriteNode }.forEach { $0.setPressed(false) }

        if let button = startButton, button.contains(location) {
            viewModel.startTapped()
            menuDelegate?.menuSceneDidStartGame(self)
            return
        }

        if let toggle = shopToggleButton, !toggle.isHidden, toggle.contains(location) {
            toggleShopVisibility()
            toggle.setPressed(false)
            return
        }

        if let restore = restoreButton, !restore.isHidden, restore.contains(location) {
            menuDelegate?.menuSceneDidRequestRestore(self)
            return
        }

        if let legal = legalButton, legal.contains(location) {
            legal.setPressed(false)
            presentLegalDocument(.terms)
            return
        }

        if let privacy = privacyButton, privacy.contains(location) {
            privacy.setPressed(false)
            presentLegalDocument(.privacy)
            return
        }

        if shopVisible, let product = productNodes.first(where: { !$0.isHidden && $0.contains(location) }) {
            menuDelegate?.menuScene(self, didSelectProduct: product.name ?? "")
            return
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if legalOverlay != nil {
            legalCloseButton?.setPressed(false)
            return
        }
        [startButton, shopToggleButton, legalButton, privacyButton].forEach { $0?.setPressed(false) }
        productNodes.compactMap { $0 as? SKSpriteNode }.forEach { $0.setPressed(false) }
    }

    private func interactiveButton(at location: CGPoint) -> SKSpriteNode? {
        if let start = startButton, start.contains(location) { return start }
        if let toggle = shopToggleButton, !toggle.isHidden, toggle.contains(location) { return toggle }
        if let legal = legalButton, legal.contains(location) { return legal }
        if let privacy = privacyButton, privacy.contains(location) { return privacy }
        for case let node as SKSpriteNode in productNodes where shopVisible && !node.isHidden && node.contains(location) {
            return node
        }
        return nil
    }
}

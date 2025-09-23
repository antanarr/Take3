import Foundation
import SpriteKit
import UIKit
import MobileCoreServices
import ImageIO

public protocol GameSceneDelegate: AnyObject {
    func gameSceneDidEnd(_ scene: GameScene, result: GameResult)
}

public struct GameResult {
    public let score: Int
    public let duration: TimeInterval
    public let nearMisses: Int
    public let replayData: Data?
    public let triggeredEvents: [Int]
}

public final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Nested Types

    private final class RingContainer {
        let node: SKNode
        let ring: SKShapeNode
        let radius: CGFloat
        var angularVelocity: CGFloat
        let direction: CGFloat

        init(node: SKNode, ring: SKShapeNode, radius: CGFloat, direction: CGFloat) {
            self.node = node
            self.ring = ring
            self.radius = radius
            self.direction = direction
            self.angularVelocity = 0
        }
    }

    public final class ViewModel {
        private(set) var score: Int = 0
        private(set) var currentMultiplier: CGFloat = 1.0
        private(set) var level: Int = 1
        private var scoreActions: Int = 0
        private var milestoneSet: Set<Int>
        private let analytics: AnalyticsTracking
        private let data: GameData
        private let startDate = Date()
        private let sound: SoundPlaying
        private let haptics: HapticProviding
        private(set) var nearMisses: Int = 0

        init(analytics: AnalyticsTracking,
             data: GameData,
             sound: SoundPlaying,
             haptics: HapticProviding) {
            self.analytics = analytics
            self.data = data
            self.sound = sound
            self.haptics = haptics
            self.milestoneSet = Set(GameConstants.milestoneScores)
        }

        var elapsedTime: TimeInterval { Date().timeIntervalSince(startDate) }

        var streakMultiplier: CGFloat {
            if data.dailyStreak.isMultiplierActive {
                return CGFloat(data.dailyStreak.multiplierBonus)
            }
            return 1.0
        }

        var isStreakMultiplierActive: Bool { data.dailyStreak.isMultiplierActive }

        var streakDays: Int { data.dailyStreak.streakDays }

        func totalMultiplier() -> CGFloat {
            currentMultiplier * streakMultiplier
        }

        func currentGems() -> Int { data.gems }

        var shieldPurchaseCost: Int { GameConstants.shieldPowerupGemCost }

        func attemptShieldPurchase() -> Bool {
            guard data.spendGems(shieldPurchaseCost) else { return false }
            analytics.track(.gemsSpent(amount: shieldPurchaseCost, reason: "shield_powerup"))
            return true
        }

        func reset() {
            score = 0
            currentMultiplier = 1.0
            level = 1
            scoreActions = 0
            nearMisses = 0
            milestoneSet = Set(GameConstants.milestoneScores)
        }

        func handleNearMiss() {
            nearMisses += 1
            currentMultiplier += GameConstants.nearMissMultiplierGain
            haptics.nearMiss()
            analytics.track(.nearMiss(count: nearMisses))
        }

        @discardableResult
        func handleSafePass() -> Int {
            scoreActions += 1
            let points = Int(GameConstants.scorePerAction * totalMultiplier())
            score += points
            currentMultiplier = max(1.0, currentMultiplier * GameConstants.multiplierDecayFactor)
            if scoreActions % 20 == 0 {
                level += 1
            }
            checkMilestones()
            return points
        }

        func currentSpeed() -> CGFloat {
            GameConstants.baseSpeed * pow(GameConstants.speedMultiplier, CGFloat(max(level - 1, 0)))
        }

        func currentSpawnRate() -> TimeInterval {
            max(GameConstants.minimumSpawnRate,
                GameConstants.baseSpawnRate - (TimeInterval(level - 1) * GameConstants.spawnRateReductionPerLevel))
        }

        private func checkMilestones() {
            if milestoneSet.contains(score) {
                milestoneSet.remove(score)
                let nextMilestone = score + GameConstants.milestoneStep
                milestoneSet.insert(nextMilestone)
                sound.play(.milestone)
                haptics.milestone()
            }
        }

        func registerStart() {
            analytics.track(.gameStart(level: level))
            sound.play(.gameStart)
        }

        func registerCollision() {
            analytics.track(.gameOver(score: score, duration: elapsedTime))
            haptics.collision()
            sound.play(.collision)
        }

        func registerFlip() {
            sound.play(.playerFlip)
            haptics.playerAction()
        }

        func registerPowerup(_ powerup: PowerUp) {
            analytics.track(.powerupUsed(type: powerup))
            sound.play(.powerupCollect)
        }

        func finalizeScore() {
            if score > data.highScore {
                data.highScore = score
            }
        }
    }

    private final class ObstaclePool {
        private var available: [SKShapeNode] = []
        private var active: Set<SKShapeNode> = []
        private let assetGenerator: AssetGenerating

        init(assetGenerator: AssetGenerating) {
            self.assetGenerator = assetGenerator
        }

        func spawn() -> SKShapeNode {
            let node: SKShapeNode
            if let reused = available.popLast() {
                node = reused
            } else {
                node = assetGenerator.makeObstacleNode(size: CGSize(width: 36, height: 42))
            }
            node.alpha = 1.0
            node.isHidden = false
            node.userData = NSMutableDictionary()
            active.insert(node)
            return node
        }

        func recycle(_ node: SKShapeNode) {
            node.removeAllActions()
            node.removeFromParent()
            node.userData?.removeAllObjects()
            active.remove(node)
            available.append(node)
        }

        func allActive() -> [SKShapeNode] {
            Array(active)
        }
    }

    public final class ReplayRecorder {
        private struct Frame {
            let texture: SKTexture
            let timestamp: TimeInterval
        }

        private var frames: [Frame] = []
        private var accumulator: TimeInterval = 0

        public init() {}

        public func update(deltaTime: TimeInterval, scene: SKScene) {
            accumulator += deltaTime
            guard accumulator >= GameConstants.frameCaptureInterval else { return }
            accumulator = 0
            guard let view = scene.view,
                  let texture = view.texture(from: scene) else { return }
            let timestamp = CACurrentMediaTime()
            frames.append(Frame(texture: texture, timestamp: timestamp))
            purgeOldFrames(reference: timestamp)
        }

        private func purgeOldFrames(reference: TimeInterval) {
            let threshold = reference - GameConstants.replayDuration
            frames.removeAll { $0.timestamp < threshold }
        }

        public func generateGIF() -> Data? {
            guard !frames.isEmpty else { return nil }
            let frameDelay = GameConstants.frameCaptureInterval
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, kUTTypeGIF, frames.count, nil) else { return nil }
            let loopDict = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary
            CGImageDestinationSetProperties(destination, loopDict)
            for frame in frames {
                guard let cgImage = frame.texture.cgImage() else { continue }
                let frameDict = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frameDelay]] as CFDictionary
                CGImageDestinationAddImage(destination, cgImage, frameDict)
            }
            CGImageDestinationFinalize(destination)
            return data as Data
        }
    }

    // MARK: - Properties

    public weak var gameDelegate: GameSceneDelegate?

    private let viewModel: ViewModel
    private let assets: AssetGenerating
    private let sound: SoundPlaying
    private let haptics: HapticProviding
    private let powerups: PowerupManaging
    private let obstaclePool: ObstaclePool
    private let replayRecorder = ReplayRecorder()

    private var backgroundNode: SKSpriteNode?
    private var ringContainers: [RingContainer] = []
    private var playerNode: SKShapeNode!
    private var ghostNode: SKShapeNode?
    private var socialProofLabel: SKLabelNode?
    private var scoreLabel: SKLabelNode?
    private var multiplierLabel: SKLabelNode?
    private var levelLabel: SKLabelNode?
    private var powerupLabel: SKLabelNode?
    private var streakLabel: SKLabelNode?
    private var streakBadge: SKShapeNode?
    private var eventBanner: SKLabelNode?
    private var shieldAura: SKShapeNode?
    private var inversionOverlay: SKSpriteNode?
    private var gemLabel: SKLabelNode?
    private var shieldPurchaseButton: SKSpriteNode?
    private var lastKnownGemBalance: Int = 0

    private var lastUpdate: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0
    private var specialEventsTriggered: Set<Int> = []
    private var isGameOver = false

    private var lastTapTime: TimeInterval = 0
    private var touchBeganTime: TimeInterval?
    private var doubleFlipArmed = false
    private var doubleFlipReadyTime: TimeInterval = 0
    private var activeRingCount = 1
    private var tutorialObstaclesRemaining = GameConstants.tutorialGhostObstacles

    private var meteorShowerEnds: TimeInterval = 0
    private var inversionEnds: TimeInterval = 0
    private var gravityEnds: TimeInterval = 0
    private var ringDirections: [CGFloat] = [1, -1, 1]

    private var powerUpNodes: [SKShapeNode] = []

    private var activePowerupTypes: Set<PowerUpType> = []
    private var lastKnownLevel: Int = 1
    private var lastStreakActive: Bool = false
    private var lastStreakMultiplier: CGFloat = 1.0

    private let streakPulseActionKey = "streakPulse"
    private lazy var nearMissTexture: SKTexture? = assets.makeParticleTexture(radius: 6, color: GamePalette.solarGold)
    private lazy var scoreBurstTexture: SKTexture? = assets.makeParticleTexture(radius: 4, color: GamePalette.neonMagenta)

    private var currentTimeSnapshot: TimeInterval = 0

    // MARK: - Initialization

    public init(size: CGSize,
                viewModel: ViewModel,
                assets: AssetGenerating,
                sound: SoundPlaying,
                haptics: HapticProviding,
                powerups: PowerupManaging) {
        self.viewModel = viewModel
        self.assets = assets
        self.sound = sound
        self.haptics = haptics
        self.powerups = powerups
        self.obstaclePool = ObstaclePool(assetGenerator: assets)
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Scene Lifecycle

    public override func didMove(to view: SKView) {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = GamePalette.deepNavy

        let background = assets.makeBackground(size: view.bounds.size)
        addChild(background)
        backgroundNode = background

        configureRings()
        configurePlayer()
        configureGhost()
        configureSocialProof()
        configureHUD()

        viewModel.reset()
        lastKnownLevel = viewModel.level
        lastStreakActive = viewModel.isStreakMultiplierActive
        lastStreakMultiplier = viewModel.streakMultiplier
        activePowerupTypes = Set(powerups.activeTypes)
        updateHUD()
        updatePowerupHUDIfNeeded()
        viewModel.registerStart()
        specialEventsTriggered.removeAll()
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
    }

    private func configureRings() {
        ringContainers.removeAll()
        for (index, radius) in GameConstants.ringRadii.enumerated() {
            let container = SKNode()
            container.zPosition = CGFloat(index) - 1
            let color = index % 2 == 0 ? GamePalette.cyan : GamePalette.neonMagenta
            let ring = assets.makeRingNode(radius: radius,
                                           lineWidth: GameConstants.ringStrokeWidth,
                                           color: color,
                                           glow: 10)
            container.addChild(ring)
            addChild(container)
            ringContainers.append(RingContainer(node: container, ring: ring, radius: radius, direction: ringDirections[index]))
            container.alpha = index == 0 ? 1.0 : 0.0
        }
        activeRingCount = 1
    }

    private func configurePlayer() {
        playerNode = assets.makePlayerNode()
        guard let firstRing = ringContainers.first else { return }
        firstRing.node.addChild(playerNode)
        playerNode.position = CGPoint(x: firstRing.radius, y: 0)
    }

    private func configureGhost() {
        let ghost = SKShapeNode(circleOfRadius: 32)
        ghost.fillColor = GamePalette.solarGold.withAlphaComponent(0.1)
        ghost.strokeColor = GamePalette.solarGold
        ghost.lineWidth = 2
        ghost.alpha = 0.3
        ghost.zPosition = 5
        ghost.name = "ghost"
        addChild(ghost)
        ghostNode = ghost
        ghost.isHidden = false
    }

    private func configureSocialProof() {
        let names = ["Sarah", "Alex", "Priya", "Noah", "Luna", "Kai"]
        let name = names.randomElement() ?? "Sarah"
        let label = SKLabelNode(text: "\(name) just beat your score! Reclaim it?")
        label.fontName = "SFProRounded-Bold"
        label.fontSize = 16
        label.fontColor = GamePalette.neonMagenta
        label.position = CGPoint(x: 0, y: size.height * 0.35)
        label.alpha = 0
        addChild(label)
        socialProofLabel = label
        let sequence = SKAction.sequence([
            SKAction.wait(forDuration: 5.0),
            SKAction.fadeIn(withDuration: 0.5),
            SKAction.wait(forDuration: 2.5),
            SKAction.fadeOut(withDuration: 0.5)
        ])
        label.run(SKAction.repeatForever(sequence))
    }

    private func configureHUD() {
        scoreLabel?.removeFromParent()
        multiplierLabel?.removeFromParent()
        levelLabel?.removeFromParent()
        powerupLabel?.removeFromParent()
        streakLabel?.removeFromParent()
        streakBadge?.removeFromParent()
        eventBanner?.removeFromParent()
        gemLabel?.removeFromParent()
        shieldPurchaseButton?.removeFromParent()

        let score = SKLabelNode(fontNamed: "Orbitron-Bold")
        score.fontSize = 28
        score.fontColor = .white
        score.text = "Score: 0"
        score.verticalAlignmentMode = .center
        score.horizontalAlignmentMode = .center
        score.zPosition = 50
        addChild(score)
        scoreLabel = score

        let multiplier = SKLabelNode(fontNamed: "SFProRounded-Bold")
        multiplier.fontSize = 18
        multiplier.fontColor = GamePalette.cyan
        multiplier.text = "Multiplier: x1.0"
        multiplier.verticalAlignmentMode = .center
        multiplier.horizontalAlignmentMode = .center
        multiplier.zPosition = 50
        addChild(multiplier)
        multiplierLabel = multiplier

        let level = SKLabelNode(fontNamed: "SFProRounded-Bold")
        level.fontSize = 18
        level.fontColor = GamePalette.solarGold
        level.text = "Level 1"
        level.verticalAlignmentMode = .center
        level.horizontalAlignmentMode = .center
        level.zPosition = 50
        addChild(level)
        levelLabel = level

        let power = SKLabelNode(fontNamed: "SFProRounded-Regular")
        power.fontSize = 14
        power.fontColor = UIColor.white.withAlphaComponent(0.8)
        power.text = "Power-ups: None"
        power.verticalAlignmentMode = .center
        power.horizontalAlignmentMode = .center
        power.zPosition = 50
        addChild(power)
        powerupLabel = power

        let gems = SKLabelNode(fontNamed: "Orbitron-Bold")
        gems.fontSize = 18
        gems.fontColor = GamePalette.cyan
        gems.horizontalAlignmentMode = .right
        gems.zPosition = 50
        gems.text = "Gems: \(viewModel.currentGems())"
        addChild(gems)
        gemLabel = gems
        lastKnownGemBalance = viewModel.currentGems()

        let shieldButton = assets.makeButtonNode(text: "Shield (\(viewModel.shieldPurchaseCost) gems)", size: CGSize(width: 240, height: 58))
        shieldButton.name = "shield_store"
        shieldButton.zPosition = 50
        addChild(shieldButton)
        shieldPurchaseButton = shieldButton
        updateShieldStoreState()

        let badge = SKShapeNode(rectOf: CGSize(width: 200, height: 40), cornerRadius: 20)
        badge.fillColor = GamePalette.solarGold.withAlphaComponent(0.15)
        badge.strokeColor = GamePalette.solarGold
        badge.lineWidth = 2
        badge.alpha = 0.4
        badge.zPosition = 50
        addChild(badge)
        streakBadge = badge

        let streakText = SKLabelNode(fontNamed: "SFProRounded-Bold")
        streakText.fontSize = 16
        streakText.fontColor = GamePalette.solarGold
        streakText.verticalAlignmentMode = .center
        streakText.horizontalAlignmentMode = .center
        streakText.text = "Streak Ready"
        streakText.zPosition = 51
        badge.addChild(streakText)
        streakLabel = streakText

        let banner = SKLabelNode(fontNamed: "Orbitron-Bold")
        banner.fontSize = 20
        banner.fontColor = GamePalette.solarGold
        banner.verticalAlignmentMode = .center
        banner.horizontalAlignmentMode = .center
        banner.alpha = 0
        banner.zPosition = 60
        addChild(banner)
        eventBanner = banner

        layoutHUD()
    }

    private func layoutHUD() {
        let topY = size.height * 0.42
        levelLabel?.position = CGPoint(x: -size.width * 0.35, y: topY)
        scoreLabel?.position = CGPoint(x: 0, y: topY)
        multiplierLabel?.position = CGPoint(x: 0, y: topY - 36)
        gemLabel?.position = CGPoint(x: size.width * 0.45, y: topY)
        if let badge = streakBadge {
            badge.position = CGPoint(x: size.width * 0.35, y: topY)
        }
        powerupLabel?.position = CGPoint(x: 0, y: -size.height * 0.45)
        shieldPurchaseButton?.position = CGPoint(x: size.width * 0.35, y: -size.height * 0.4)
        eventBanner?.position = CGPoint(x: 0, y: size.height * 0.28)
        inversionOverlay?.position = .zero
        inversionOverlay?.size = size
    }

    private func updateHUD() {
        scoreLabel?.text = "Score: \(viewModel.score)"
        let totalMultiplier = Double(viewModel.totalMultiplier())
        multiplierLabel?.text = String(format: "Multiplier: x%.1f", totalMultiplier)
        levelLabel?.text = "Level \(viewModel.level)"
        updateStreakBadge()
    }

    private func updateStreakBadge() {
        guard let badge = streakBadge, let label = streakLabel else { return }
        if viewModel.isStreakMultiplierActive {
            let multiplier = Double(viewModel.streakMultiplier)
            label.text = String(format: "Streak x%.1f • %dd", multiplier, viewModel.streakDays)
            badge.alpha = 1.0
            if badge.action(forKey: streakPulseActionKey) == nil {
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.05, duration: 0.45),
                    SKAction.scale(to: 1.0, duration: 0.45)
                ])
                badge.run(SKAction.repeatForever(pulse), withKey: streakPulseActionKey)
            }
        } else {
            label.text = "Build your streak"
            badge.alpha = 0.4
            badge.removeAction(forKey: streakPulseActionKey)
            badge.setScale(1.0)
        }
    }

    private func updatePowerupHUDIfNeeded() {
        let current = Set(powerups.activeTypes)
        guard current != activePowerupTypes else { return }
        activePowerupTypes = current
        if current.isEmpty {
            powerupLabel?.text = "Power-ups: None"
            powerupLabel?.fontColor = UIColor.white.withAlphaComponent(0.8)
        } else {
            let names = current.map { $0.displayName }.sorted()
            powerupLabel?.text = "Power-ups: " + names.joined(separator: ", ")
            powerupLabel?.fontColor = GamePalette.cyan
        }
        updateShieldStoreState()
    }

    private func updateShieldAura() {
        let shieldActive = powerups.isActive(.shield, currentTime: currentTimeSnapshot)
        if shieldActive {
            guard shieldAura == nil else { return }
            let radius = max(playerNode.frame.width / 2 + 14, 24)
            let aura = SKShapeNode(circleOfRadius: radius)
            aura.strokeColor = GamePalette.cyan
            aura.fillColor = GamePalette.cyan.withAlphaComponent(0.15)
            aura.lineWidth = 3
            aura.glowWidth = 8
            aura.alpha = 0
            aura.zPosition = -1
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.05, duration: 0.4),
                SKAction.scale(to: 1.0, duration: 0.4)
            ])
            aura.run(SKAction.repeatForever(pulse))
            aura.run(SKAction.fadeIn(withDuration: 0.2))
            playerNode.addChild(aura)
            shieldAura = aura
        } else if let aura = shieldAura {
            aura.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))
            shieldAura = nil
        }
    }

    private func updateGemBalanceDisplay() {
        let balance = viewModel.currentGems()
        if balance != lastKnownGemBalance {
            lastKnownGemBalance = balance
            gemLabel?.text = "Gems: \(balance)"
        }
    }

    private func updateShieldStoreState() {
        guard let button = shieldPurchaseButton else { return }
        let canAfford = viewModel.currentGems() >= viewModel.shieldPurchaseCost
        let shieldActive = powerups.isActive(.shield, currentTime: currentTimeSnapshot)
        let enabled = !isGameOver && canAfford && !shieldActive
        button.alpha = enabled ? 1.0 : 0.4
        if let label = button.childNode(withName: "label") as? SKLabelNode {
            label.text = "Shield (\(viewModel.shieldPurchaseCost) gems)"
        }
    }

    private func attemptShieldPurchase() {
        guard !isGameOver else { return }
        if powerups.isActive(.shield, currentTime: currentTimeSnapshot) {
            showEventBanner("Shield already active")
            return
        }
        if viewModel.attemptShieldPurchase() {
            updateGemBalanceDisplay()
            powerups.activate(.shield(duration: GameConstants.shieldPowerupDuration), currentTime: currentTimeSnapshot)
            updateShieldAura()
            updatePowerupHUDIfNeeded()
            showEventBanner("Shield activated!")
        } else {
            showEventBanner("Not enough gems for shield")
        }
        updateShieldStoreState()
    }

    private func nodesContainShieldButton(_ nodes: [SKNode]) -> Bool {
        guard let button = shieldPurchaseButton else { return false }
        return nodes.contains(where: { $0 == button || ($0.name == "label" && $0.parent == button) })
    }

    private func emitNearMiss(at position: CGPoint) {
        guard let texture = nearMissTexture else { return }
        let emitter = SKEmitterNode()
        emitter.particleTexture = texture
        emitter.numParticlesToEmit = 28
        emitter.particleLifetime = 0.6
        emitter.particleBirthRate = 200
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.2
        emitter.particleSpeed = 120
        emitter.particleSpeedRange = 40
        emitter.particleScale = 0.35
        emitter.particleScaleSpeed = -0.2
        emitter.particleColorBlendFactor = 1
        emitter.particleColor = GamePalette.solarGold
        emitter.position = position
        emitter.zPosition = 80
        addChild(emitter)
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.7),
            SKAction.removeFromParent()
        ]))
    }

    private func showScorePopup(for points: Int, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "SFProRounded-Bold")
        label.fontSize = 16
        label.fontColor = GamePalette.solarGold
        label.text = "+\(points)"
        label.position = position
        label.zPosition = 80
        label.alpha = 0
        addChild(label)
        let rise = SKAction.moveBy(x: 0, y: 32, duration: 0.6)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        label.run(SKAction.sequence([
            fadeIn,
            SKAction.group([rise, fadeOut]),
            SKAction.removeFromParent()
        ]))

        if let texture = scoreBurstTexture {
            let emitter = SKEmitterNode()
            emitter.particleTexture = texture
            emitter.numParticlesToEmit = 18
            emitter.particleLifetime = 0.4
            emitter.particleBirthRate = 150
            emitter.particleAlpha = 0.8
            emitter.particleAlphaSpeed = -1.5
            emitter.particleSpeed = 90
            emitter.particleScale = 0.3
            emitter.particleScaleSpeed = -0.2
            emitter.particleColorBlendFactor = 1
            emitter.particleColor = GamePalette.neonMagenta
            emitter.position = position
            emitter.zPosition = 75
            addChild(emitter)
            emitter.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.5),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func showEventBanner(_ text: String) {
        guard let banner = eventBanner else { return }
        banner.text = text
        banner.removeAllActions()
        banner.alpha = 0
        banner.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.wait(forDuration: 1.8),
            SKAction.fadeOut(withDuration: 0.3)
        ]))
    }

    private func refreshStreakIfNeeded() {
        let active = viewModel.isStreakMultiplierActive
        let multiplier = viewModel.streakMultiplier
        if active != lastStreakActive || abs(multiplier - lastStreakMultiplier) > 0.001 {
            lastStreakActive = active
            lastStreakMultiplier = multiplier
            updateHUD()
        }
    }

    // MARK: - Touch Handling

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        let touchedNodes = nodes(at: location)
        if nodesContainShieldButton(touchedNodes) {
            shieldPurchaseButton?.setPressed(true)
            return
        }
        guard !isGameOver else { return }
        touchBeganTime = currentTimeSnapshot
        doubleFlipArmed = false
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameOver, let start = touchBeganTime else { return }
        if !doubleFlipArmed && currentTimeSnapshot - start >= GameConstants.doubleFlipHoldThreshold {
            doubleFlipArmed = true
            doubleFlipReadyTime = currentTimeSnapshot
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        shieldPurchaseButton?.setPressed(false)
        let touchedNodes = nodes(at: location)
        if nodesContainShieldButton(touchedNodes) {
            attemptShieldPurchase()
            return
        }
        guard !isGameOver else { return }
        defer { touchBeganTime = nil }
        let now = currentTimeSnapshot
        if doubleFlipArmed && now - doubleFlipReadyTime <= GameConstants.doubleFlipReleaseWindow {
            performFlip(doubleJump: true)
        } else {
            performFlip(doubleJump: false)
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        shieldPurchaseButton?.setPressed(false)
        guard !isGameOver else { return }
        touchBeganTime = nil
        doubleFlipArmed = false
    }

    private func performFlip(doubleJump: Bool) {
        guard currentTimeSnapshot - lastTapTime >= GameConstants.tapCooldown else { return }
        guard let parent = playerNode.parent, let currentIndex = ringContainers.firstIndex(where: { $0.node == parent }) else { return }
        var step = doubleJump ? 2 : 1
        if currentIndex >= activeRingCount - 1 {
            step = -step
        }
        var targetIndex = currentIndex + step
        if targetIndex < 0 {
            targetIndex = min(activeRingCount - 1, currentIndex + abs(step))
        } else if targetIndex >= activeRingCount {
            targetIndex = max(0, currentIndex - abs(step))
        }
        guard targetIndex != currentIndex else { return }
        let targetRing = ringContainers[targetIndex]
        let converted = parent.convert(playerNode.position, to: self)
        let local = convert(converted, to: targetRing.node)
        playerNode.removeFromParent()
        targetRing.node.addChild(playerNode)
        let destination = local.normalized(to: targetRing.radius)
        playerNode.position = destination
        let move = SKAction.move(to: destination, duration: 0.12)
        move.timingMode = .easeInEaseOut
        playerNode.run(move)
        lastTapTime = currentTimeSnapshot
        viewModel.registerFlip()
        if doubleJump {
            sound.play(.nearMiss)
        }
    }

    // MARK: - Update Loop

    public override func update(_ currentTime: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = currentTime }
        let delta = currentTime - lastUpdate
        lastUpdate = currentTime
        currentTimeSnapshot = currentTime
        guard !isGameOver else { return }

        if let start = touchBeganTime, !doubleFlipArmed && currentTime - start >= GameConstants.doubleFlipHoldThreshold {
            doubleFlipArmed = true
            doubleFlipReadyTime = currentTime
        }

        if gravityEnds > 0 && currentTime >= gravityEnds {
            gravityEnds = 0
        }
        if meteorShowerEnds > 0 && currentTime >= meteorShowerEnds {
            meteorShowerEnds = 0
        }
        if inversionEnds > 0 && currentTime >= inversionEnds {
            inversionEnds = 0
        }

        replayRecorder.update(deltaTime: delta, scene: self)

        updateRings(delta: delta)
        updateSpawn(delta: delta, currentTime: currentTime)
        updateObstacles(currentTime: currentTime)
        updatePowerups(currentTime: currentTime)
        updateGhostFollowing()
        applyMagnetIfNeeded(delta: delta)
        updateShieldAura()
        updatePowerupHUDIfNeeded()
        refreshStreakIfNeeded()
        handleSpecialEvents()
        updateGemBalanceDisplay()
        updateShieldStoreState()
    }

    private func updateRings(delta: TimeInterval) {
        var speed = viewModel.currentSpeed()
        if let slow = powerups.currentPowerUp(of: .slowMo)?.slowFactor {
            speed *= slow
        }
        for (index, container) in ringContainers.enumerated() {
            guard index < activeRingCount else {
                container.node.alpha = max(container.node.alpha - CGFloat(delta) * 2.0, 0.0)
                continue
            }
            container.node.alpha = min(container.node.alpha + CGFloat(delta) * 2.0, 1.0)
            let direction = gravityEnds > 0 && currentTimeSnapshot < gravityEnds ? -container.direction : container.direction
            let angularVelocity = (speed / container.radius) * direction
            container.node.zRotation += angularVelocity * CGFloat(delta)
        }
    }

    private func updateSpawn(delta: TimeInterval, currentTime: TimeInterval) {
        spawnTimer += delta
        var spawnRate = meteorShowerEnds > currentTime ? max(0.2, viewModel.currentSpawnRate() * 0.6) : viewModel.currentSpawnRate()
        if let slow = powerups.currentPowerUp(of: .slowMo)?.slowFactor, slow > 0 {
            spawnRate /= Double(slow)
        }
        while spawnTimer >= spawnRate {
            spawnTimer -= spawnRate
            spawnObstacle(at: currentTime)
        }
    }

    private func spawnObstacle(at time: TimeInterval, colorOverride: UIColor? = nil) {
        guard let (ring, index) = availableRingForSpawn() else { return }
        let obstacle = obstaclePool.spawn()
        let angle = CGFloat.random(in: 0...(2 * .pi))
        obstacle.zRotation = angle
        obstacle.position = CGPoint(x: cos(angle) * ring.radius, y: sin(angle) * ring.radius)
        if let override = colorOverride {
            obstacle.fillColor = override
            obstacle.strokeColor = override
        } else {
            obstacle.fillColor = GamePalette.solarGold
            obstacle.strokeColor = GamePalette.cyan
        }
        ring.node.addChild(obstacle)
        obstacle.userData?["spawn"] = time
        obstacle.userData?["near"] = false
        obstacle.userData?["ringIndex"] = index
        if tutorialObstaclesRemaining > 0 {
            tutorialObstaclesRemaining -= 1
            showGhostGuidance(for: obstacle, on: ring)
        }
        if Int.random(in: 0..<100) < 8 {
            spawnPowerUp(on: ring, angle: angle + .pi / 4)
        }
    }

    private func availableRingForSpawn() -> (RingContainer, Int)? {
        adjustActiveRingsIfNeeded()
        let rings = Array(ringContainers.prefix(activeRingCount))
        guard !rings.isEmpty else { return nil }
        let index = Int.random(in: 0..<rings.count)
        return (rings[index], index)
    }

    private func adjustActiveRingsIfNeeded() {
        let newActive: Int
        if viewModel.level <= 3 {
            newActive = 1
        } else if viewModel.level <= 6 {
            newActive = 2
        } else {
            newActive = GameConstants.maxRings
        }
        if newActive != activeRingCount {
            activeRingCount = newActive
        }
    }

    private func spawnPowerUp(on ring: RingContainer, angle: CGFloat) {
        let typeRoll = Int.random(in: 0..<3)
        let type: PowerUpType
        switch typeRoll {
        case 0: type = .shield
        case 1: type = .slowMo
        default: type = .magnet
        }
        let node = assets.makePowerUpNode(of: type)
        node.position = CGPoint(x: cos(angle) * ring.radius, y: sin(angle) * ring.radius)
        ring.node.addChild(node)
        node.userData = ["spawn": currentTimeSnapshot, "type": type.rawValue]
        powerUpNodes.append(node)
    }

    private func updateObstacles(currentTime: TimeInterval) {
        for obstacle in obstaclePool.allActive() {
            guard let spawnTime = obstacle.userData?["spawn"] as? TimeInterval else { continue }
            if currentTime - spawnTime > 6.0 {
                obstacleCleared(obstacle)
                continue
            }
            handleNearMissCheck(for: obstacle)
        }
    }

    private func obstacleCleared(_ obstacle: SKShapeNode) {
        let points = viewModel.handleSafePass()
        obstaclePool.recycle(obstacle)
        updateHUD()
        let playerPosition = playerNode.parent?.convert(playerNode.position, to: self) ?? .zero
        showScorePopup(for: points, at: playerPosition)
        if viewModel.level != lastKnownLevel {
            lastKnownLevel = viewModel.level
            showEventBanner("Level \(viewModel.level) unlocked")
        }
    }

    private func handleNearMissCheck(for obstacle: SKShapeNode) {
        let playerPosition = playerNode.parent?.convert(playerNode.position, to: self) ?? .zero
        let obstaclePosition = obstacle.parent?.convert(obstacle.position, to: self) ?? .zero
        let distance = hypot(playerPosition.x - obstaclePosition.x, playerPosition.y - obstaclePosition.y)
        let alreadyNear = obstacle.userData?["near"] as? Bool ?? false
        if distance < GameConstants.nearMissDistance && !alreadyNear {
            obstacle.userData?["near"] = true
            viewModel.handleNearMiss()
            sound.play(.nearMiss)
            updateHUD()
            emitNearMiss(at: playerPosition)
        }
    }

    private func updatePowerups(currentTime: TimeInterval) {
        powerups.update(currentTime: currentTime)
        for (index, node) in powerUpNodes.enumerated().reversed() {
            let playerPosition = playerNode.parent?.convert(playerNode.position, to: self) ?? .zero
            let nodePosition = node.parent?.convert(node.position, to: self) ?? .zero
            let distance = hypot(playerPosition.x - nodePosition.x, playerPosition.y - nodePosition.y)
            if distance < 36 {
                applyPowerUp(node)
                powerUpNodes.remove(at: index)
            } else if let spawn = node.userData?["spawn"] as? TimeInterval, currentTime - spawn > 5.0 {
                node.removeFromParent()
                powerUpNodes.remove(at: index)
            }
        }
    }

    private func applyPowerUp(_ node: SKShapeNode) {
        guard let type = determinePowerUpType(from: node) else { return }
        node.removeFromParent()
        let currentTime = currentTimeSnapshot
        let powerUp: PowerUp
        switch type {
        case .shield:
            powerUp = .shield(duration: GameConstants.powerupShieldDuration)
        case .slowMo:
            powerUp = .slowMo(factor: GameConstants.powerupSlowFactor, duration: GameConstants.powerupShieldDuration)
        case .magnet:
            powerUp = .magnet(strength: GameConstants.magnetStrength, duration: GameConstants.powerupShieldDuration)
        }
        powerups.activate(powerUp, currentTime: currentTime)
        viewModel.registerPowerup(powerUp)
        updatePowerupHUDIfNeeded()
        updateShieldAura()
    }

    private func determinePowerUpType(from node: SKShapeNode) -> PowerUpType? {
        guard let raw = node.userData?["type"] as? String,
              let type = PowerUpType(rawValue: raw) else { return nil }
        return type
    }

    private func updateGhostFollowing() {
        guard let ghost = ghostNode, tutorialObstaclesRemaining > 0 else {
            ghostNode?.removeFromParent()
            ghostNode = nil
            return
        }
        guard let ring = ringContainers.first else { return }
        let angle = playerNode.parent?.convert(playerNode.position, to: ring.node) ?? .zero
        let currentAngle = atan2(angle.y, angle.x)
        let ghostTarget = CGPoint(x: cos(currentAngle) * (ring.radius + 30), y: sin(currentAngle) * (ring.radius + 30))
        let action = SKAction.move(to: ghostTarget, duration: 0.3)
        action.timingMode = .easeInEaseOut
        ghost.run(action)
    }

    private func showGhostGuidance(for obstacle: SKShapeNode, on ring: RingContainer) {
        guard let ghost = ghostNode else { return }
        let obstaclePosition = obstacle.parent?.convert(obstacle.position, to: self) ?? .zero
        let angle = atan2(obstaclePosition.y, obstaclePosition.x)
        let safeAngle = angle + (.pi / 2)
        let points = [CGPoint(x: cos(angle) * (ring.radius + 20), y: sin(angle) * (ring.radius + 20)),
                      CGPoint(x: cos(safeAngle) * (ring.radius + 20), y: sin(safeAngle) * (ring.radius + 20))]
        let path = CGMutablePath()
        path.move(to: points[0])
        path.addLine(to: points[1])
        let follow = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.6)
        follow.timingMode = .easeInEaseOut
        ghost.run(follow)
    }

    private func applyMagnetIfNeeded(delta: TimeInterval) {
        guard let magnet = powerups.currentPowerUp(of: .magnet),
              let strength = magnet.magnetStrength,
              powerups.isActive(.magnet, currentTime: currentTimeSnapshot) else { return }
        let obstacles = obstaclePool.allActive()
        guard !obstacles.isEmpty, let parent = playerNode.parent else { return }
        let playerPosition = parent.convert(playerNode.position, to: self)
        guard let obstacle = obstacles.min(by: { lhs, rhs in
            let left = lhs.parent?.convert(lhs.position, to: self) ?? .zero
            let right = rhs.parent?.convert(rhs.position, to: self) ?? .zero
            return playerPosition.distance(to: left) < playerPosition.distance(to: right)
        }) else { return }
        let obstaclePosition = obstacle.parent?.convert(obstacle.position, to: self) ?? .zero
        let safeAngle = atan2(obstaclePosition.y, obstaclePosition.x) + (.pi / 2)
        let currentAngle = atan2(playerPosition.y, playerPosition.x)
        let difference = shortestAngleBetween(currentAngle, safeAngle)
        guard abs(difference) > 0.001 else { return }
        let clampStrength = min(0.35, max(0.1, strength / 200.0))
        let adjustment = difference * clampStrength * CGFloat(delta * 60.0)
        let radius = playerPosition.length()
        guard radius > GameConstants.magnetSafeZoneRadius else { return }
        let newAngle = currentAngle + adjustment
        let newPosition = CGPoint(x: cos(newAngle) * radius, y: sin(newAngle) * radius)
        playerNode.position = convert(newPosition, to: parent)
    }

    private func handleSpecialEvents() {
        let score = viewModel.score
        if score >= 69 && !specialEventsTriggered.contains(69) {
            specialEventsTriggered.insert(69)
            triggerColorInversion()
        }
        if score >= 420 && !specialEventsTriggered.contains(420) {
            specialEventsTriggered.insert(420)
            triggerMeteorShower()
        }
        if score >= 999 && !specialEventsTriggered.contains(999) {
            specialEventsTriggered.insert(999)
            triggerGravityReversal()
        }
    }

    private func triggerColorInversion() {
        inversionEnds = currentTimeSnapshot + GameConstants.inversionDuration
        let overlay: SKSpriteNode
        if let existing = inversionOverlay {
            overlay = existing
        } else {
            overlay = SKSpriteNode(color: .white, size: size)
            overlay.blendMode = .difference
            overlay.zPosition = 100
            overlay.alpha = 0
            addChild(overlay)
            inversionOverlay = overlay
        }
        overlay.removeAllActions()
        overlay.position = .zero
        overlay.size = size
        let duration = GameConstants.inversionDuration
        overlay.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.3),
            SKAction.wait(forDuration: max(0, duration - 0.6)),
            SKAction.fadeAlpha(to: 0.0, duration: 0.3),
            SKAction.run { [weak self] in
                guard let self else { return }
                if self.currentTimeSnapshot >= self.inversionEnds {
                    self.inversionOverlay?.removeFromParent()
                    self.inversionOverlay = nil
                }
                self.inversionEnds = 0
            }
        ]))
        showEventBanner("Color inversion!")
    }

    private func triggerMeteorShower() {
        meteorShowerEnds = currentTimeSnapshot + GameConstants.meteorShowerDuration
        for _ in 0..<10 {
            let rainbow = UIColor(hue: CGFloat.random(in: 0...1), saturation: 0.9, brightness: 1.0, alpha: 1.0)
            spawnObstacle(at: currentTimeSnapshot, colorOverride: rainbow)
        }
        showEventBanner("Rainbow meteor shower!")
    }

    private func triggerGravityReversal() {
        gravityEnds = currentTimeSnapshot + GameConstants.gravityReversalDuration
        showEventBanner("Gravity reversed!")
    }

    // MARK: - Contact Handling

    public func didBegin(_ contact: SKPhysicsContact) {
        guard !isGameOver else { return }
        let bodies = [contact.bodyA, contact.bodyB]
        if bodies.contains(where: { $0.categoryBitMask == PhysicsCategory.obstacle }) &&
            bodies.contains(where: { $0.categoryBitMask == PhysicsCategory.player }) {
            handleCollision(withShieldCheck: powerups.isActive(.shield, currentTime: currentTimeSnapshot))
        }
        if bodies.contains(where: { $0.categoryBitMask == PhysicsCategory.powerUp }) &&
            bodies.contains(where: { $0.categoryBitMask == PhysicsCategory.player }) {
            if let powerUpNode = (bodies.first { $0.categoryBitMask == PhysicsCategory.powerUp }?.node) as? SKShapeNode {
                applyPowerUp(powerUpNode)
            }
        }
    }

    private func handleCollision(withShieldCheck hasShield: Bool) {
        if hasShield {
            sound.play(.collision)
            return
        }
        shake(intensity: 6.0)
        endGame()
    }

    private func endGame() {
        guard !isGameOver else { return }
        isGameOver = true
        updateShieldStoreState()
        viewModel.registerCollision()
        viewModel.finalizeScore()
        shieldAura?.removeAllActions()
        shieldAura?.removeFromParent()
        shieldAura = nil
        inversionOverlay?.removeAllActions()
        inversionOverlay?.removeFromParent()
        inversionOverlay = nil
        inversionEnds = 0
        eventBanner?.removeAllActions()
        eventBanner?.alpha = 0
        let result = GameResult(score: viewModel.score,
                                duration: viewModel.elapsedTime,
                                nearMisses: viewModel.nearMisses,
                                replayData: replayRecorder.generateGIF(),
                                triggeredEvents: Array(specialEventsTriggered))
        gameDelegate?.gameSceneDidEnd(self, result: result)
    }

    // MARK: - Revive

    public func revivePlayer(withShield: Bool) {
        guard isGameOver else { return }
        isGameOver = false
        if withShield {
            powerups.activate(.shield(duration: GameConstants.powerupShieldDuration), currentTime: currentTimeSnapshot)
        }
        updateShieldAura()
        updatePowerupHUDIfNeeded()
        updateHUD()
        spawnTimer = 0
        specialEventsTriggered.removeAll()
        obstaclePool.allActive().forEach { obstaclePool.recycle($0) }
        lastTapTime = currentTimeSnapshot
    }
}

private extension CGPoint {
    func length() -> CGFloat {
        sqrt(x * x + y * y)
    }

    func normalized(to radius: CGFloat) -> CGPoint {
        let currentLength = length()
        guard currentLength > 0 else { return CGPoint(x: radius, y: 0) }
        let scale = radius / currentLength
        return CGPoint(x: x * scale, y: y * scale)
    }

    func distance(to point: CGPoint) -> CGFloat {
        hypot(point.x - x, point.y - y)
    }
}

private func shortestAngleBetween(_ angle1: CGFloat, _ angle2: CGFloat) -> CGFloat {
    var difference = angle2 - angle1
    while difference > .pi { difference -= 2 * .pi }
    while difference < -.pi { difference += 2 * .pi }
    return difference
}

public extension SKScene {
    func shake(intensity: CGFloat = 5.0) {
        let sequence = SKAction.sequence([
            SKAction.moveBy(x: intensity, y: 0, duration: 0.05),
            SKAction.moveBy(x: -intensity * 2, y: 0, duration: 0.05),
            SKAction.moveBy(x: intensity, y: 0, duration: 0.05)
        ])
        run(sequence)
    }
}

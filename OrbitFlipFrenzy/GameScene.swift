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
    public let challenge: Challenge?
}

public final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Nested Types

    public final class ViewModel {
        private(set) var score: Int = 0
        private(set) var level: Int = 1
        private(set) var currentMultiplier: CGFloat = 1.0
        private var scoreActions: Int = 0
        private let analytics: AnalyticsTracking
        private let data: GameData
        private let sound: SoundPlaying
        private let haptics: HapticProviding
        private var milestones: Set<Int>
        private let startDate = Date()
        private(set) var nearMisses: Int = 0

        init(analytics: AnalyticsTracking,
             data: GameData,
             sound: SoundPlaying,
             haptics: HapticProviding) {
            self.analytics = analytics
            self.data = data
            self.sound = sound
            self.haptics = haptics
            self.milestones = Set(GameConstants.milestoneScores)
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

        func reset() {
            score = 0
            level = 1
            currentMultiplier = 1.0
            scoreActions = 0
            nearMisses = 0
            milestones = Set(GameConstants.milestoneScores)
        }

        func currentGems() -> Int { data.gems }

        func spendGems(_ amount: Int) -> Bool {
            guard data.gems >= amount else { return false }
            data.gems -= amount
            return true
        }

        func addGems(_ amount: Int) {
            data.gems += amount
        }

        func registerStart() {
            analytics.track(.gameStart(level: level))
            sound.play(.gameStart)
        }

        func registerFlip() {
            sound.play(.playerFlip)
            haptics.playerAction()
        }

        func registerCollision() {
            analytics.track(.gameOver(score: score, duration: elapsedTime))
            haptics.collision()
            sound.play(.collision)
        }

        func registerPowerup(_ powerup: PowerUpType) {
            analytics.track(.powerupUsed(type: powerup))
            sound.play(.powerupCollect)
            haptics.playerAction()
        }

        func handleNearMiss() {
            nearMisses += 1
            currentMultiplier += GameConstants.nearMissMultiplierGain
            analytics.track(.nearMiss(count: nearMisses))
            haptics.nearMiss()
        }

        @discardableResult
        func handleSafePass() -> Int {
            scoreActions += 1
            let earned = Int(GameConstants.scorePerAction * totalMultiplier())
            score += earned
            currentMultiplier = max(1.0, currentMultiplier * GameConstants.multiplierDecayFactor)
            if scoreActions % 20 == 0 { level += 1 }
            checkMilestones()
            return earned
        }

        func finalizeScore() {
            if score > data.highScore {
                data.highScore = score
            }
        }

        func currentSpeed() -> CGFloat {
            GameConstants.baseSpeed * pow(GameConstants.speedMultiplier, CGFloat(max(level - 1, 0)))
        }

        func currentSpawnInterval() -> TimeInterval {
            max(GameConstants.minimumSpawnRate,
                GameConstants.baseSpawnRate - (TimeInterval(level) * GameConstants.spawnRateReductionPerLevel))
        }

        private func checkMilestones() {
            if milestones.contains(score) {
                milestones.remove(score)
                let next = score + GameConstants.milestoneStep
                milestones.insert(next)
                sound.play(.milestone)
                haptics.milestone()
            }
        }
    }

    private final class ObstaclePool {
        private let generator: AssetGenerating
        private let size: CGSize
        private let capacity: Int
        private var available: [SKShapeNode] = []
        private var active: Set<SKShapeNode> = []

        init(generator: AssetGenerating, size: CGSize, capacity: Int) {
            self.generator = generator
            self.size = size
            self.capacity = capacity
        }

        func prewarm() {
            if available.count >= capacity { return }
            for _ in available.count..<capacity {
                let node = generator.makeObstacleNode(size: size)
                node.isHidden = true
                available.append(node)
            }
        }

        func spawn() -> SKShapeNode {
            let node = available.popLast() ?? generator.makeObstacleNode(size: size)
            node.removeAllActions()
            node.alpha = 1
            node.isHidden = false
            node.zRotation = 0
            node.userData = node.userData ?? NSMutableDictionary()
            active.insert(node)
            return node
        }

        func recycle(_ node: SKShapeNode) {
            node.removeAllActions()
            node.removeAllChildren()
            node.removeFromParent()
            node.alpha = 1
            node.isHidden = true
            active.remove(node)
            if available.count < capacity { available.append(node) }
        }

        func recycleAll() {
            for node in active { recycle(node) }
        }

        func activeNodes() -> [SKShapeNode] { Array(active) }
    }

    public final class ReplayRecorder {
        private struct Frame {
            let texture: SKTexture
            let timestamp: TimeInterval
        }

        private var frames: [Frame] = []
        private var accumulator: TimeInterval = 0

        public init() {}

        public func reset() {
            frames.removeAll(keepingCapacity: false)
            accumulator = 0
        }

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
            let cutoff = reference - GameConstants.replayDuration
            frames.removeAll { $0.timestamp < cutoff }
        }

        public func generateGIF() -> Data? {
            guard !frames.isEmpty else { return nil }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, kUTTypeGIF, frames.count, nil) else { return nil }
            let gifInfo = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary
            CGImageDestinationSetProperties(destination, gifInfo)
            let delay = GameConstants.frameCaptureInterval
            for frame in frames {
                guard let cgImage = frame.texture.cgImage() else { continue }
                let frameDict = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary
                CGImageDestinationAddImage(destination, cgImage, frameDict)
            }
            CGImageDestinationFinalize(destination)
            let result = data as Data
            if !result.isEmpty {
                print("Generated shareable GIF (\(frames.count) frames)")
            }
            return result
        }
    }

    // MARK: - Dependencies

    public weak var gameDelegate: GameSceneDelegate?

    private let viewModel: ViewModel
    private let assets: AssetGenerating
    private let sound: SoundPlaying
    private let haptics: HapticProviding
    private let powerups: PowerupManaging
    private let adManager: AdManaging
    private let obstaclePool: ObstaclePool
    private let replayRecorder = ReplayRecorder()

    // MARK: - Nodes

    private var backgroundNode: SKSpriteNode?
    private var ringContainers: [SKNode] = []
    private var ringDirections: [CGFloat] = [1, -1, 1]
    private var playerNode: SKShapeNode!
    private var ghostNode: SKNode?

    private var scoreStat: HUDStatNode?
    private var multiplierStat: HUDStatNode?
    private var levelStat: HUDStatNode?
    private var powerupStat: HUDStatNode?
    private var streakBadge: SKSpriteNode?
    private var eventBanner: EventBannerNode?
    private var gemLabel: SKLabelNode?
    private var shieldButton: SKSpriteNode?

    private var shieldAura: SKShapeNode?
    private var inversionOverlay: SKSpriteNode?
    private var meteorEmitter: SKEmitterNode?

    // MARK: - State

    private var currentRingIndex = 0
    private var activeRingCount = 1
    private var spawnTimer: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var isGameOver = false
    private var isPausedForInterruption = false

    private var touchStartTime: TimeInterval?
    private var doubleFlipArmed = false
    private var lastTapTime: TimeInterval = 0

    private var specialEventsTriggered: Set<Int> = []
    private var meteorShowerEnds: TimeInterval = 0
    private var inversionEnds: TimeInterval = 0
    private var gravityEnds: TimeInterval = 0
    private var currentChallengeSeed: UInt32 = UInt32.random(in: UInt32.min...UInt32.max)

    private var scoreFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private var activePowerups: Set<PowerUpType> = []

    // MARK: - Initialization

    public init(size: CGSize,
                viewModel: ViewModel,
                assets: AssetGenerating,
                sound: SoundPlaying,
                haptics: HapticProviding,
                powerups: PowerupManaging,
                adManager: AdManaging) {
        self.viewModel = viewModel
        self.assets = assets
        self.sound = sound
        self.haptics = haptics
        self.powerups = powerups
        self.adManager = adManager
        self.obstaclePool = ObstaclePool(generator: assets,
                                         size: GameConstants.obstacleSize,
                                         capacity: GameConstants.obstaclePoolMaxStored)
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Scene Lifecycle

    public override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = GamePalette.deepNavy
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        obstaclePool.recycleAll()
        obstaclePool.prewarm()
        replayRecorder.reset()
        powerups.reset()
        activePowerups.removeAll()
        viewModel.reset()
        specialEventsTriggered.removeAll()
        currentChallengeSeed = UInt32.random(in: UInt32.min...UInt32.max)

        removeAllChildren()
        configureBackground()
        configureRings()
        configurePlayer()
        configureGhost()
        configureHUD()

        spawnTimer = 0
        lastUpdateTime = 0
        currentRingIndex = 0
        activeRingCount = 1
        isGameOver = false
        isPausedForInterruption = false
        meteorShowerEnds = 0
        inversionEnds = 0
        gravityEnds = 0
        lastTapTime = 0
        doubleFlipArmed = false
        touchStartTime = nil

        viewModel.registerStart()
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
    }

    // MARK: - Configuration

    private func configureBackground() {
        let node = assets.makeBackground(size: CGSize(width: size.width * 2, height: size.height * 2))
        addChild(node)
        backgroundNode = node
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
            ring.alpha = index == 0 ? 1.0 : 0.0
            addChild(container)
            ringContainers.append(container)
        }
    }

    private func configurePlayer() {
        playerNode = assets.makePlayerNode()
        playerNode.zPosition = 10
        addChild(playerNode)
        positionPlayer(onRing: currentRingIndex, animated: false)
    }

    private func configureGhost() {
        let ghost = assets.makeGhostNode(radius: 32)
        ghost.alpha = 0.0
        addChild(ghost)
        ghostNode = ghost
        let fade = SKAction.sequence([
            SKAction.wait(forDuration: 0.4),
            SKAction.fadeAlpha(to: 0.45, duration: 0.4)
        ])
        ghost.run(fade)
    }

    private func configureHUD() {
        let statSize = CGSize(width: min(size.width * 0.28, 200), height: 64)
        let levelNode = assets.makeHUDStatNode(title: "Level",
                                               value: "1",
                                               size: statSize,
                                               icon: .level,
                                               accent: GamePalette.cyan)
        levelNode.position = CGPoint(x: -size.width * 0.3, y: size.height * 0.35)
        addChild(levelNode)
        levelStat = levelNode

        let scoreNode = assets.makeHUDStatNode(title: "Score",
                                               value: "0",
                                               size: statSize,
                                               icon: .trophy,
                                               accent: GamePalette.solarGold)
        scoreNode.position = CGPoint(x: 0, y: size.height * 0.35)
        addChild(scoreNode)
        scoreStat = scoreNode

        let multiplierNode = assets.makeHUDStatNode(title: "Multiplier",
                                                    value: "x1.0",
                                                    size: statSize,
                                                    icon: .streak,
                                                    accent: GamePalette.neonMagenta)
        multiplierNode.position = CGPoint(x: size.width * 0.3, y: size.height * 0.35)
        addChild(multiplierNode)
        multiplierStat = multiplierNode

        let powerSize = CGSize(width: min(size.width * 0.6, 320), height: 64)
        let powerNode = assets.makeHUDStatNode(title: "Power-Ups",
                                               value: "None",
                                               size: powerSize,
                                               icon: .power,
                                               accent: GamePalette.cyan)
        powerNode.position = CGPoint(x: 0, y: -size.height * 0.42)
        addChild(powerNode)
        powerupStat = powerNode

        let streakSize = CGSize(width: min(size.width * 0.45, 240), height: 60)
        let streakNode = assets.makeBadgeNode(title: "Daily Streak",
                                              subtitle: "Play daily to boost rewards",
                                              size: streakSize,
                                              icon: .streak)
        streakNode.position = CGPoint(x: size.width * 0.32, y: size.height * 0.2)
        addChild(streakNode)
        streakBadge = streakNode

        let banner = assets.makeEventBanner(size: CGSize(width: min(size.width * 0.7, 340), height: 56), icon: .alert)
        banner.position = CGPoint(x: 0, y: size.height * 0.25)
        addChild(banner)
        eventBanner = banner

        let gemLabel = SKLabelNode(fontNamed: "Orbitron-Bold")
        gemLabel.fontSize = 18
        gemLabel.fontColor = GamePalette.cyan
        gemLabel.horizontalAlignmentMode = .right
        gemLabel.verticalAlignmentMode = .center
        gemLabel.position = CGPoint(x: size.width * 0.45, y: size.height * 0.35)
        addChild(gemLabel)
        self.gemLabel = gemLabel

        let button = assets.makeButtonNode(text: "Shield (\(GameConstants.shieldPowerupGemCost) gems)",
                                           size: CGSize(width: 240, height: 56),
                                           icon: .gems)
        button.position = CGPoint(x: size.width * 0.35, y: -size.height * 0.35)
        button.name = "shield_button"
        addChild(button)
        shieldButton = button

        updateHUD(force: true)
        updateStreakBadge()
        updateGemLabel()
        updateShieldStoreState()
    }

    private func layoutHUD() {
        scoreStat?.position = CGPoint(x: 0, y: size.height * 0.35)
        levelStat?.position = CGPoint(x: -size.width * 0.32, y: size.height * 0.35)
        multiplierStat?.position = CGPoint(x: size.width * 0.32, y: size.height * 0.35)
        powerupStat?.position = CGPoint(x: 0, y: -size.height * 0.42)
        streakBadge?.position = CGPoint(x: size.width * 0.32, y: size.height * 0.2)
        gemLabel?.position = CGPoint(x: size.width * 0.45, y: size.height * 0.35)
        shieldButton?.position = CGPoint(x: size.width * 0.35, y: -size.height * 0.35)
        eventBanner?.position = CGPoint(x: 0, y: size.height * 0.25)
        backgroundNode?.size = CGSize(width: size.width * 2, height: size.height * 2)
        inversionOverlay?.size = size
    }

    // MARK: - Input

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameOver else { return }
        touchStartTime = touches.first?.timestamp
        if let touch = touches.first {
            let location = touch.location(in: self)
            if let node = nodes(at: location).first(where: { $0 == shieldButton }) {
                node.setPressed(true)
            }
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let start = touchStartTime else { return }
        if touch.timestamp - start > GameConstants.doubleFlipHoldThreshold {
            doubleFlipArmed = true
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        shieldButton?.setPressed(false)
        let location = touch.location(in: self)
        if let button = shieldButton, button.contains(location) {
            attemptShieldPurchase()
            touchStartTime = nil
            doubleFlipArmed = false
            return
        }
        guard !isGameOver else { return }
        handleFlipInput(timestamp: touch.timestamp)
        touchStartTime = nil
        doubleFlipArmed = false
    }

    private func handleFlipInput(timestamp: TimeInterval) {
        guard timestamp - lastTapTime >= GameConstants.tapCooldown else { return }
        lastTapTime = timestamp
        if doubleFlipArmed && timestamp - (touchStartTime ?? timestamp) <= GameConstants.doubleFlipHoldThreshold + GameConstants.doubleFlipReleaseWindow {
            performDoubleFlip()
        } else {
            flipToAdjacentRing()
        }
    }

    // MARK: - Game Loop

    public override func update(_ currentTime: TimeInterval) {
        guard !isPausedForInterruption else { return }
        let delta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        guard !isGameOver else { return }

        replayRecorder.update(deltaTime: delta, scene: self)
        powerups.update(currentTime: currentTime)
        updateActivePowerups(currentTime: currentTime)
        updateShieldAura(currentTime: currentTime)
        updateSpecialEvents(currentTime: currentTime)

        spawnTimer += delta * (powerups.isActive(.slowMo, currentTime: currentTime) ? 0.5 : 1.0)
        if spawnTimer >= viewModel.currentSpawnInterval() {
            spawnTimer = 0
            spawnObstacle()
        }

        updateObstacles(delta: delta, currentTime: currentTime)
        updateGhostAssist(delta: delta)
    }

    private func updateGhostAssist(delta: TimeInterval) {
        guard let ghost = ghostNode else { return }
        if viewModel.level > 3 || ghost.hasActions() { return }
        let radius = GameConstants.ringRadii[currentRingIndex]
        let angle = playerNode.zRotation + CGFloat(delta * 1.5)
        let position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        ghost.run(SKAction.move(to: position, duration: 0.2))
    }

    private func updateObstacles(delta: TimeInterval, currentTime: TimeInterval) {
        let speed = viewModel.currentSpeed()
        for node in obstaclePool.activeNodes() {
            node.position.y -= speed * CGFloat(delta)
            if node.position.y < -size.height {
                obstaclePool.recycle(node)
                continue
            }
            if let passed = node.userData?["passed"] as? Bool, !passed, node.position.y < playerNode.position.y {
                node.userData?["passed"] = true
                handleScoreProgression()
            }
            checkNearMiss(for: node, currentTime: currentTime)
        }
    }

    private func updateActivePowerups(currentTime: TimeInterval) {
        let newActive = Set(powerups.activeTypes)
        if newActive != activePowerups {
            activePowerups = newActive
            updatePowerupHUDIfNeeded()
            updateShieldStoreState()
        }
    }

    private func updateShieldAura(currentTime: TimeInterval) {
        let shieldActive = powerups.isActive(.shield, currentTime: currentTime)
        if shieldActive {
            if shieldAura == nil {
                let radius = max(playerNode.frame.width / 2 + 12, 24)
                let aura = SKShapeNode(circleOfRadius: radius)
                aura.strokeColor = GamePalette.cyan
                aura.fillColor = GamePalette.cyan.withAlphaComponent(0.18)
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
            }
        } else if let aura = shieldAura {
            aura.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))
            shieldAura = nil
        }
    }

    private func updateSpecialEvents(currentTime: TimeInterval) {
        if meteorShowerEnds > 0, currentTime > meteorShowerEnds {
            meteorEmitter?.removeFromParent()
            meteorEmitter = nil
            meteorShowerEnds = 0
            showEventBanner("Meteor storm cleared", accent: GamePalette.cyan)
        }
        if inversionEnds > 0, currentTime > inversionEnds {
            inversionOverlay?.removeFromParent()
            inversionOverlay = nil
            inversionEnds = 0
            showEventBanner("Colors restored", accent: GamePalette.cyan)
        }
        if gravityEnds > 0, currentTime > gravityEnds {
            physicsWorld.gravity = .zero
            gravityEnds = 0
            showEventBanner("Gravity normalized", accent: GamePalette.cyan)
        }
    }

    // MARK: - Obstacles & Powerups

    private func spawnObstacle() {
        let node = obstaclePool.spawn()
        let radius = GameConstants.ringRadii.randomElement() ?? GameConstants.ringRadii[0]
        let angle = CGFloat.random(in: 0..<(2 * .pi))
        node.position = CGPoint(x: cos(angle) * radius, y: size.height * 0.6)
        node.userData?["passed"] = false
        addChild(node)

        let lifetime = GameConstants.obstacleLifetime
        let move = SKAction.moveBy(x: 0, y: -size.height - 200, duration: lifetime)
        let cleanup = SKAction.run { [weak self, weak node] in
            guard let self, let node else { return }
            self.obstaclePool.recycle(node)
        }
        node.run(SKAction.sequence([move, cleanup]))

        if Int.random(in: 0..<5) == 0 {
            spawnPowerup(at: angle, radius: radius * 0.8)
        }
    }

    private func spawnPowerup(at angle: CGFloat, radius: CGFloat) {
        let types: [PowerUpType] = [.shield, .slowMo, .magnet]
        guard let type = types.randomElement() else { return }
        let node = assets.makePowerUpNode(of: type)
        node.position = CGPoint(x: cos(angle) * radius, y: size.height * 0.55)
        node.userData = ["type": type.rawValue]
        addChild(node)
        let lifetime = SKAction.sequence([
            SKAction.wait(forDuration: 6.0),
            SKAction.fadeOut(withDuration: 0.4),
            SKAction.removeFromParent()
        ])
        node.run(lifetime)
    }

    private func activatePowerup(_ type: PowerUpType, currentTime: TimeInterval) {
        switch type {
        case .shield:
            powerups.activate(.shield(duration: GameConstants.powerupShieldDuration), currentTime: currentTime)
        case .slowMo:
            powerups.activate(.slowMo(factor: GameConstants.powerupSlowFactor, duration: 4.0), currentTime: currentTime)
        case .magnet:
            powerups.activate(.magnet(strength: GameConstants.magnetStrength, duration: 5.0), currentTime: currentTime)
        }
        viewModel.registerPowerup(type)
        showEventBanner("\(type.displayName) activated!", accent: GamePalette.cyan)
        updatePowerupHUDIfNeeded()
    }

    private func updatePowerupHUDIfNeeded() {
        let types = activePowerups
        guard let stat = powerupStat else { return }
        if types.isEmpty {
            stat.updateValue("None")
            stat.setHighlighted(false)
            return
        }
        let names = types.map { $0.displayName }.joined(separator: ", ")
        stat.updateValue(names)
        stat.setHighlighted(true)
    }

    // MARK: - Gameplay Actions

    private func flipToAdjacentRing() {
        let target: Int
        if currentRingIndex >= activeRingCount - 1 {
            target = 0
        } else {
            target = currentRingIndex + 1
        }
        performRingTransition(to: target)
    }

    private func performDoubleFlip() {
        let target = min(activeRingCount - 1, currentRingIndex + 2)
        performRingTransition(to: target)
    }

    private func performRingTransition(to index: Int) {
        guard index != currentRingIndex else { return }
        currentRingIndex = index
        positionPlayer(onRing: index, animated: true)
        viewModel.registerFlip()
    }

    private func positionPlayer(onRing index: Int, animated: Bool) {
        let radius = GameConstants.ringRadii[index]
        let target = CGPoint(x: radius, y: 0)
        if animated {
            let move = SKAction.move(to: target, duration: 0.2)
            move.timingMode = .easeOut
            playerNode.run(move)
        } else {
            playerNode.position = target
        }
        for (idx, container) in ringContainers.enumerated() {
            let alpha: CGFloat
            if idx < activeRingCount {
                alpha = idx == index ? 1.0 : 0.3
            } else {
                alpha = 0
            }
            container.run(SKAction.fadeAlpha(to: alpha, duration: 0.25))
        }
    }

    private func attemptShieldPurchase() {
        guard !isGameOver else { return }
        if powerups.isActive(.shield, currentTime: lastUpdateTime) {
            showEventBanner("Shield already active", accent: GamePalette.cyan)
            return
        }
        guard viewModel.spendGems(GameConstants.shieldPowerupGemCost) else {
            showEventBanner("Not enough gems", accent: .systemRed)
            return
        }
        powerups.activate(.shield(duration: GameConstants.powerupShieldDuration), currentTime: lastUpdateTime)
        viewModel.registerPowerup(.shield)
        showEventBanner("Shield purchased!", accent: GamePalette.cyan)
        updateGemLabel()
        updateShieldStoreState()
        updatePowerupHUDIfNeeded()
    }

    private func updateShieldStoreState() {
        guard let button = shieldButton else { return }
        let affordable = viewModel.currentGems() >= GameConstants.shieldPowerupGemCost
        let shieldActive = powerups.isActive(.shield, currentTime: lastUpdateTime)
        button.alpha = affordable && !shieldActive && !isGameOver ? 1.0 : 0.4
    }

    private func checkNearMiss(for obstacle: SKShapeNode, currentTime: TimeInterval) {
        guard !isGameOver else { return }
        let distance = hypot(obstacle.position.x - playerNode.position.x,
                             obstacle.position.y - playerNode.position.y)
        if distance < GameConstants.nearMissDistance {
            emitNearMiss(at: obstacle.position)
            viewModel.handleNearMiss()
            multiplierStat?.setHighlighted(true)
            updateHUD(force: false)
        }
    }

    private func emitNearMiss(at position: CGPoint) {
        guard let texture = assets.makeParticleTexture(radius: 5, color: GamePalette.solarGold) else { return }
        let emitter = SKEmitterNode()
        emitter.particleTexture = texture
        emitter.particleBirthRate = 140
        emitter.particleLifetime = 0.4
        emitter.particleAlphaSpeed = -2.0
        emitter.particleSpeed = 60
        emitter.particleScale = 0.6
        emitter.particleScaleSpeed = -1.2
        emitter.position = position
        emitter.zPosition = 5
        addChild(emitter)
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }

    private func showEventBanner(_ message: String, accent: UIColor = GamePalette.solarGold) {
        eventBanner?.present(message: message, accent: accent)
    }

    private func updateHUD(force: Bool) {
        levelStat?.updateValue("\(viewModel.level)")
        scoreStat?.updateValue(scoreFormatter.string(from: NSNumber(value: viewModel.score)) ?? "\(viewModel.score)")
        let multiplierText = String(format: "x%.1f", viewModel.totalMultiplier())
        multiplierStat?.updateValue(multiplierText)
        multiplierStat?.setHighlighted(viewModel.totalMultiplier() > 1.0 || viewModel.isStreakMultiplierActive)
        if force { updatePowerupHUDIfNeeded() }
        updateGemLabel()
        updateShieldStoreState()
        updateStreakBadge()
    }

    private func updateGemLabel() {
        gemLabel?.text = "Gems: \(viewModel.currentGems())"
    }

    private func updateStreakBadge() {
        guard let badge = streakBadge else { return }
        let title = "Daily Streak: \(viewModel.streakDays)d"
        let active = viewModel.isStreakMultiplierActive
        let subtitle = active ? String(format: "Multiplier x%.1f active", viewModel.streakMultiplier) : "Play again tomorrow"
        (badge.childNode(withName: "badgeTitle") as? SKLabelNode)?.text = title
        (badge.childNode(withName: "badgeSubtitle") as? SKLabelNode)?.text = subtitle
        badge.alpha = active ? 1.0 : 0.6
    }

    // MARK: - Collision Handling

    public func didBegin(_ contact: SKPhysicsContact) {
        guard !isGameOver else { return }
        let bodies = [contact.bodyA, contact.bodyB]
        if bodies.contains(where: { $0.categoryBitMask == PhysicsCategory.powerUp }) {
            if let powerNode = bodies.first(where: { $0.categoryBitMask == PhysicsCategory.powerUp })?.node as? SKShapeNode {
                handlePowerupCollision(node: powerNode)
            }
            return
        }
        if bodies.contains(where: { $0.categoryBitMask == PhysicsCategory.obstacle }) {
            handleObstacleCollision()
        }
    }

    private func handlePowerupCollision(node: SKShapeNode) {
        node.removeAllActions()
        node.removeFromParent()
        guard let rawType = node.userData?["type"] as? String,
              let type = PowerUpType(rawValue: rawType) else { return }
        activatePowerup(type, currentTime: lastUpdateTime)
    }

    private func handleObstacleCollision() {
        if powerups.isActive(.shield, currentTime: lastUpdateTime) {
            powerups.deactivate(.shield)
            updatePowerupHUDIfNeeded()
            showEventBanner("Shield absorbed the hit!", accent: GamePalette.cyan)
            return
        }
        isGameOver = true
        obstaclePool.recycleAll()
        viewModel.registerCollision()
        viewModel.finalizeScore()
        let replay = replayRecorder.generateGIF()
        let challenge = Challenge(seed: currentChallengeSeed,
                                  targetScore: max(10, viewModel.score))
        let result = GameResult(score: viewModel.score,
                                duration: viewModel.elapsedTime,
                                nearMisses: viewModel.nearMisses,
                                replayData: replay,
                                triggeredEvents: Array(specialEventsTriggered),
                                challenge: challenge)
        currentChallengeSeed = UInt32.random(in: UInt32.min...UInt32.max)
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.4),
            SKAction.run { [weak self] in
                guard let self else { return }
                self.gameDelegate?.gameSceneDidEnd(self, result: result)
            }
        ]))
    }

    // MARK: - Special Events

    private func evaluateSpecialEvents() {
        let score = viewModel.score
        if score >= 69, !specialEventsTriggered.contains(69) {
            triggerColorInversion()
        }
        if score >= 420, !specialEventsTriggered.contains(420) {
            triggerMeteorShower()
        }
        if score >= 999, !specialEventsTriggered.contains(999) {
            triggerGravityFlip()
        }
    }

    private func triggerColorInversion() {
        specialEventsTriggered.insert(69)
        inversionEnds = lastUpdateTime + GameConstants.inversionDuration
        let overlay = SKSpriteNode(color: .white, size: size)
        overlay.alpha = 0
        overlay.zPosition = 100
        overlay.blendMode = .difference
        addChild(overlay)
        overlay.run(SKAction.fadeAlpha(to: 0.65, duration: 0.3))
        inversionOverlay = overlay
        showEventBanner("Color inversion!", accent: GamePalette.neonMagenta)
    }

    private func triggerMeteorShower() {
        specialEventsTriggered.insert(420)
        meteorShowerEnds = lastUpdateTime + GameConstants.meteorShowerDuration
        let emitter = SKEmitterNode()
        emitter.particleTexture = assets.makeParticleTexture(radius: 3, color: .white)
        emitter.particleBirthRate = 80
        emitter.particleLifetime = 1.2
        emitter.particleSpeed = 200
        emitter.particleSpeedRange = 40
        emitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
        emitter.emissionAngle = -.pi / 3
        emitter.position = CGPoint(x: 0, y: size.height / 2)
        emitter.zPosition = 20
        addChild(emitter)
        meteorEmitter = emitter
        showEventBanner("Meteor shower!", accent: GamePalette.solarGold)
    }

    private func triggerGravityFlip() {
        specialEventsTriggered.insert(999)
        gravityEnds = lastUpdateTime + GameConstants.gravityReversalDuration
        physicsWorld.gravity = CGVector(dx: 0, dy: GameConstants.baseSpeed)
        showEventBanner("Gravity reversed!", accent: GamePalette.neonMagenta)
    }

    // MARK: - Revive & Pause

    public func revivePlayer(withShield: Bool) {
        guard isGameOver else { return }
        isGameOver = false
        if withShield {
            powerups.activate(.shield(duration: GameConstants.powerupShieldDuration), currentTime: lastUpdateTime)
            updatePowerupHUDIfNeeded()
        }
        playerNode.position = CGPoint(x: GameConstants.ringRadii[currentRingIndex], y: 0)
        obstaclePool.recycleAll()
        spawnTimer = 0
        showEventBanner("Revived!", accent: GamePalette.cyan)
    }

    public func pauseForInterruption() {
        isPausedForInterruption = true
        isPaused = true
    }

    public func resumeFromInterruption() {
        guard isPausedForInterruption else { return }
        isPausedForInterruption = false
        isPaused = false
        lastUpdateTime = 0
    }

    // MARK: - Helpers

    private func handleScoreProgression() {
        viewModel.handleSafePass()
        updateHUD(force: false)
        evaluateRingUnlock()
        evaluateSpecialEvents()
    }

    private func evaluateRingUnlock() {
        let targetRings: Int
        if viewModel.level <= 3 {
            targetRings = 1
        } else if viewModel.level <= 6 {
            targetRings = 2
        } else {
            targetRings = GameConstants.maxRings
        }
        if targetRings != activeRingCount {
            activeRingCount = targetRings
            showEventBanner("New orbit unlocked!", accent: GamePalette.cyan)
            if currentRingIndex >= activeRingCount {
                currentRingIndex = activeRingCount - 1
                positionPlayer(onRing: currentRingIndex, animated: true)
            }
        }
    }
}

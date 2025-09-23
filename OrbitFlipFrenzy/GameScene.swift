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
            max(
                GameConstants.minimumSpawnRate,
                GameConstants.baseSpawnRate - (TimeInterval(level) * GameConstants.spawnRateReductionPerLevel)
            )
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
            haptics.playerAction()
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
    private var meteorEmitter: SKEmitterNode?

    private var lastUpdate: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0
    private var specialEventsTriggered: Set<Int> = []
    private var isGameOver = false

    private var lastTapTime: TimeInterval = 0
    private var touchBeganTime: TimeInterval?
    private var doubleFlipArmed = false
    private var doubleFlipReadyTime: TimeInterval = 0
    private var activeRingCount = 1
    private var currentRingIndex = 0
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
    private lazy var meteorParticleTexture: SKTexture? = assets.makeParticleTexture(radius: 3, color: .white)
    private lazy var shieldBreakTexture: SKTexture? = assets.makeParticleTexture(radius: 5, color: GamePalette.cyan)

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

        powerups.reset()
        powerUpNodes.forEach { $0.removeFromParent() }
        powerUpNodes.removeAll()

        viewModel.reset()
        isGameOver = false
        spawnTimer = 0
        lastUpdate = 0
        lastKnownLevel = viewModel.level
        lastStreakActive = viewModel.isStreakMultiplierActive
        lastStreakMultiplier = viewModel.streakMultiplier
        activePowerupTypes = Set(powerups.activeTypes)
        updateHUD()
        updatePowerupHUD()
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
        playerNode.zPosition = 40
        addChild(playerNode)
        currentRingIndex = 0
        positionPlayer(onRing: currentRingIndex, animated: false)
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
        streakBadge?.removeFromParent()
        eventBanner?.removeFromParent()

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
        if let badge = streakBadge {
            badge.position = CGPoint(x: size.width * 0.35, y: topY)
        }
        powerupLabel?.position = CGPoint(x: 0, y: -size.height * 0.45)
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

    private func updatePowerupHUD() {
        let current = Set(powerups.activeTypes)
        if current.isEmpty {
            if !activePowerupTypes.isEmpty {
                powerupLabel?.text = "Power-ups: None"
                powerupLabel?.fontColor = UIColor.white.withAlphaComponent(0.8)
            }
            activePowerupTypes = []
            return
        }

        activePowerupTypes = current
        var highlightLowTime = false
        let descriptions = current.sorted { $0.displayName < $1.displayName }.map { type -> String in
            if let remaining = powerups.timeRemaining(for: type, currentTime: currentTimeSnapshot) {
                let clamped = max(0, remaining)
                if clamped < 1.0 { highlightLowTime = true }
                return "\(type.displayName) " + String(format: "%.1fs", clamped)
            }
            return type.displayName
        }
        powerupLabel?.text = "Power-ups: " + descriptions.joined(separator: ", ")
        powerupLabel?.fontColor = highlightLowTime ? GamePalette.solarGold : GamePalette.cyan
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

    private func playerWorldPosition() -> CGPoint {
        playerNode.position
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

    private func showShieldBreak(at position: CGPoint) {
        guard let texture = shieldBreakTexture else { return }
        let emitter = SKEmitterNode()
        emitter.particleTexture = texture
        emitter.numParticlesToEmit = 32
        emitter.particleLifetime = 0.45
        emitter.particleBirthRate = 200
        emitter.particleAlpha = 0.85
        emitter.particleAlphaSpeed = -1.6
        emitter.particleSpeed = 160
        emitter.particleSpeedRange = 60
        emitter.particleScale = 0.4
        emitter.particleScaleSpeed = -0.3
        emitter.particleColorBlendFactor = 1
        emitter.particleColor = GamePalette.cyan
        emitter.position = position
        emitter.zPosition = 85
        addChild(emitter)
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.35),
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
        guard !isGameOver else { return }
        defer { touchBeganTime = nil }
        let now = currentTimeSnapshot
        if doubleFlipArmed && now - doubleFlipReadyTime <= GameConstants.doubleFlipReleaseWindow {
            performFlip(doubleJump: true)
        } else {
            performFlip(doubleJump: false)
        }
        doubleFlipArmed = false
        doubleFlipReadyTime = 0
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameOver else { return }
        touchBeganTime = nil
        doubleFlipArmed = false
    }

    private func positionPlayer(onRing index: Int, animated: Bool) {
        guard ringContainers.indices.contains(index) else { return }
        let radius = ringContainers[index].radius
        let angle = atan2(playerNode.position.y, playerNode.position.x)
        let destination = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        playerNode.removeAction(forKey: "flip")
        if animated {
            let move = SKAction.move(to: destination, duration: 0.12)
            move.timingMode = .easeInEaseOut
            playerNode.run(move, withKey: "flip")
        } else {
            playerNode.position = destination
        }
    }

    private func performFlip(doubleJump: Bool) {
        guard currentTimeSnapshot - lastTapTime >= GameConstants.tapCooldown else { return }
        guard activeRingCount > 0 else { return }
        let currentIndex = currentRingIndex
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
        guard targetIndex != currentIndex, ringContainers.indices.contains(targetIndex) else { return }
        currentRingIndex = targetIndex
        positionPlayer(onRing: currentRingIndex, animated: true)
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
            showEventBanner("Gravity normalized")
        }
        if meteorShowerEnds > 0 && currentTime >= meteorShowerEnds {
            meteorShowerEnds = 0
            stopMeteorEmitter()
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
        updatePowerupHUD()
        refreshStreakIfNeeded()
        handleSpecialEvents()
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
        let meteorActive = meteorShowerEnds > currentTimeSnapshot
        if let override = colorOverride {
            obstacle.fillColor = override
            obstacle.strokeColor = override
        } else if meteorActive {
            let rainbow = UIColor(hue: CGFloat.random(in: 0...1), saturation: 0.9, brightness: 1.0, alpha: 1.0)
            obstacle.fillColor = rainbow
            obstacle.strokeColor = rainbow
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
            let previous = activeRingCount
            activeRingCount = newActive
            if currentRingIndex >= activeRingCount {
                currentRingIndex = max(0, activeRingCount - 1)
                positionPlayer(onRing: currentRingIndex, animated: true)
            }
            if newActive > previous {
                showEventBanner("New orbit unlocked!")
            }
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
        let playerPosition = playerWorldPosition()
        showScorePopup(for: points, at: playerPosition)
        if viewModel.level != lastKnownLevel {
            lastKnownLevel = viewModel.level
            showEventBanner("Level \(viewModel.level) unlocked")
        }
    }

    private func handleNearMissCheck(for obstacle: SKShapeNode) {
        let playerPosition = playerWorldPosition()
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
        let playerPosition = playerWorldPosition()
        for (index, node) in powerUpNodes.enumerated().reversed() {
            let nodePosition = node.parent?.convert(node.position, to: self) ?? .zero
            let distance = hypot(playerPosition.x - nodePosition.x, playerPosition.y - nodePosition.y)
            if distance < 36 {
                applyPowerUp(node)
            } else if let spawn = node.userData?["spawn"] as? TimeInterval, currentTime - spawn > 5.0 {
                node.removeFromParent()
                powerUpNodes.remove(at: index)
            }
        }
    }

    private func applyPowerUp(_ node: SKShapeNode) {
        guard let type = determinePowerUpType(from: node) else { return }
        powerUpNodes.removeAll { $0 === node }
        node.removeFromParent()
        let currentTime = currentTimeSnapshot
        let powerUp: PowerUp
        let message: String
        switch type {
        case .shield:
            powerUp = .shield(duration: GameConstants.powerupShieldDuration)
            message = "Shield online!"
        case .slowMo:
            powerUp = .slowMo(factor: GameConstants.powerupSlowFactor, duration: GameConstants.powerupShieldDuration)
            message = "Time dilated!"
        case .magnet:
            powerUp = .magnet(strength: GameConstants.magnetStrength, duration: GameConstants.powerupShieldDuration)
            message = "Magnet engaged!"
        }
        powerups.activate(powerUp, currentTime: currentTime)
        viewModel.registerPowerup(powerUp)
        updatePowerupHUD()
        updateShieldAura()
        showEventBanner(message)
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
        let angle = convert(playerNode.position, to: ring.node)
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
        guard !obstacles.isEmpty else { return }
        if playerNode.action(forKey: "flip") != nil { return }
        let playerPosition = playerWorldPosition()
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
        playerNode.position = newPosition
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
        playEventCelebration()
        showEventBanner("Color inversion!")
    }

    private func triggerMeteorShower() {
        meteorShowerEnds = currentTimeSnapshot + GameConstants.meteorShowerDuration
        startMeteorEmitter()
        for _ in 0..<10 {
            let rainbow = UIColor(hue: CGFloat.random(in: 0...1), saturation: 0.9, brightness: 1.0, alpha: 1.0)
            spawnObstacle(at: currentTimeSnapshot, colorOverride: rainbow)
        }
        playEventCelebration()
        showEventBanner("Rainbow meteor shower!")
    }

    private func triggerGravityReversal() {
        gravityEnds = currentTimeSnapshot + GameConstants.gravityReversalDuration
        playEventCelebration()
        showEventBanner("Gravity reversed!")
    }

    private func playEventCelebration() {
        sound.play(.milestone)
        haptics.milestone()
    }

    private func startMeteorEmitter() {
        stopMeteorEmitter(immediate: true)
        guard let texture = meteorParticleTexture else { return }
        let emitter = SKEmitterNode()
        emitter.particleTexture = texture
        emitter.particleBirthRate = 160
        emitter.particleLifetime = 1.2
        emitter.particleSpeed = 260
        emitter.particleSpeedRange = 90
        emitter.emissionAngle = -.pi / 2.3
        emitter.emissionAngleRange = .pi / 6
        emitter.particlePositionRange = CGVector(dx: size.width * 1.1, dy: 0)
        emitter.position = CGPoint(x: 0, y: size.height * 0.45)
        emitter.zPosition = 30
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.0
        emitter.particleScale = 0.35
        emitter.particleScaleSpeed = -0.22
        emitter.particleRotation = -.pi / 4
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        let sequence = SKKeyframeSequence(keyframeValues: [
            UIColor.red,
            UIColor.orange,
            UIColor.yellow,
            UIColor.green,
            UIColor.cyan,
            UIColor.blue,
            UIColor.purple
        ], times: [0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0].map { NSNumber(value: $0) })
        emitter.particleColorSequence = sequence
        emitter.alpha = 0
        addChild(emitter)
        emitter.run(SKAction.fadeIn(withDuration: 0.25))
        meteorEmitter = emitter
    }

    private func stopMeteorEmitter(immediate: Bool = false) {
        guard let emitter = meteorEmitter else { return }
        emitter.removeAllActions()
        if immediate {
            emitter.removeFromParent()
            meteorEmitter = nil
            return
        }
        let cleanup = SKAction.run { [weak self] in self?.meteorEmitter = nil }
        emitter.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent(),
            cleanup
        ]))
    }

    // MARK: - Contact Handling

    public func didBegin(_ contact: SKPhysicsContact) {
        guard !isGameOver else { return }
        let bodies = [contact.bodyA, contact.bodyB]
        if bodies.contains(where: { $0.categoryBitMask == PhysicsCategory.obstacle }) &&
            bodies.contains(where: { $0.categoryBitMask == PhysicsCategory.player }) {
            let obstacleNode = bodies.first(where: { $0.categoryBitMask == PhysicsCategory.obstacle })?.node as? SKShapeNode
            handleCollision(withShieldCheck: powerups.isActive(.shield, currentTime: currentTimeSnapshot),
                            obstacle: obstacleNode)
        }
        if bodies.contains(where: { $0.categoryBitMask == PhysicsCategory.powerUp }) &&
            bodies.contains(where: { $0.categoryBitMask == PhysicsCategory.player }) {
            if let powerUpNode = (bodies.first { $0.categoryBitMask == PhysicsCategory.powerUp }?.node) as? SKShapeNode {
                applyPowerUp(powerUpNode)
            }
        }
    }

    private func handleCollision(withShieldCheck hasShield: Bool, obstacle: SKShapeNode?) {
        if hasShield {
            absorbCollision(with: obstacle)
            return
        }
        shake(intensity: 6.0)
        endGame()
    }

    private func absorbCollision(with obstacle: SKShapeNode?) {
        sound.play(.collision)
        haptics.playerAction()
        let impactPosition: CGPoint
        if let obstacle {
            impactPosition = obstacle.parent?.convert(obstacle.position, to: self) ??
                playerWorldPosition()
            obstaclePool.recycle(obstacle)
        } else {
            impactPosition = playerWorldPosition()
        }
        showShieldBreak(at: impactPosition)
        let flash = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.12)
        ])
        playerNode.run(flash)
        powerups.deactivate(.shield)
        updateShieldAura()
        updatePowerupHUD()
        showEventBanner("Shield absorbed the hit!")
    }

    private func endGame() {
        guard !isGameOver else { return }
        isGameOver = true
        viewModel.registerCollision()
        viewModel.finalizeScore()
        shieldAura?.removeAllActions()
        shieldAura?.removeFromParent()
        shieldAura = nil
        inversionOverlay?.removeAllActions()
        inversionOverlay?.removeFromParent()
        inversionOverlay = nil
        stopMeteorEmitter(immediate: true)
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
        powerups.reset()
        powerUpNodes.forEach { $0.removeFromParent() }
        powerUpNodes.removeAll()
        activePowerupTypes.removeAll()
        if withShield {
            powerups.activate(.shield(duration: GameConstants.powerupShieldDuration), currentTime: currentTimeSnapshot)
        }
        stopMeteorEmitter(immediate: true)
        meteorShowerEnds = 0
        gravityEnds = 0
        inversionEnds = 0
        if activeRingCount > 0 {
            currentRingIndex = min(currentRingIndex, activeRingCount - 1)
            positionPlayer(onRing: currentRingIndex, animated: false)
        }
        updateShieldAura()
        updatePowerupHUD()
        updateHUD()
        spawnTimer = 0
        lastUpdate = currentTimeSnapshot
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

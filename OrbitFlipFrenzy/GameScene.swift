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
            let points = Int(GameConstants.scorePerAction * currentMultiplier)
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
    private let powerups: PowerupManager
    private let obstaclePool: ObstaclePool
    private let replayRecorder = ReplayRecorder()

    private var backgroundNode: SKSpriteNode?
    private var ringContainers: [RingContainer] = []
    private var playerNode: SKShapeNode!
    private var ghostNode: SKShapeNode?
    private var socialProofLabel: SKLabelNode?

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

    private var currentTimeSnapshot: TimeInterval = 0

    // MARK: - Initialization

    public init(size: CGSize,
                viewModel: ViewModel,
                assets: AssetGenerating,
                sound: SoundPlaying,
                haptics: HapticProviding,
                powerups: PowerupManager) {
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

        viewModel.reset()
        viewModel.registerStart()
        specialEventsTriggered.removeAll()
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
        applyMagnetIfNeeded()
        handleSpecialEvents()
    }

    private func updateRings(delta: TimeInterval) {
        var speed = viewModel.currentSpeed()
        if powerups.isActive(.slowMo, currentTime: currentTimeSnapshot) {
            speed *= GameConstants.powerupSlowFactor
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
        if powerups.isActive(.slowMo, currentTime: currentTimeSnapshot) {
            spawnRate *= 1.5
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
        _ = viewModel.handleSafePass()
        obstaclePool.recycle(obstacle)
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

    private func applyMagnetIfNeeded() {
        guard powerups.isActive(.magnet, currentTime: currentTimeSnapshot) else { return }
        let obstacles = obstaclePool.allActive()
        guard !obstacles.isEmpty, let parent = playerNode.parent else { return }
        let playerPosition = parent.convert(playerNode.position, to: self)
        let nearest = obstacles.min(by: { lhs, rhs in
            let left = lhs.parent?.convert(lhs.position, to: self) ?? .zero
            let right = rhs.parent?.convert(rhs.position, to: self) ?? .zero
            return playerPosition.distance(to: left) < playerPosition.distance(to: right)
        })
        guard let obstacle = nearest else { return }
        let obstaclePosition = obstacle.parent?.convert(obstacle.position, to: self) ?? .zero
        let safeAngle = atan2(obstaclePosition.y, obstaclePosition.x) + (.pi / 2)
        let currentAngle = atan2(playerPosition.y, playerPosition.x)
        let delta = shortestAngleBetween(currentAngle, safeAngle)
        let adjustedAngle = currentAngle + delta * 0.08
        let radius = playerPosition.length()
        let newPosition = CGPoint(x: cos(adjustedAngle) * radius, y: sin(adjustedAngle) * radius)
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
        let invertAction = SKAction.customAction(withDuration: GameConstants.inversionDuration) { [weak self] _, elapsed in
            guard let self else { return }
            let progress = elapsed / CGFloat(GameConstants.inversionDuration)
            self.backgroundNode?.color = UIColor.white.withAlphaComponent(progress)
            self.backgroundNode?.colorBlendFactor = progress
        }
        backgroundNode?.run(SKAction.sequence([invertAction, SKAction.run { [weak self] in
            self?.backgroundNode?.colorBlendFactor = 0
        }]))
    }

    private func triggerMeteorShower() {
        meteorShowerEnds = currentTimeSnapshot + GameConstants.meteorShowerDuration
        for _ in 0..<10 {
            let rainbow = UIColor(hue: CGFloat.random(in: 0...1), saturation: 0.9, brightness: 1.0, alpha: 1.0)
            spawnObstacle(at: currentTimeSnapshot, colorOverride: rainbow)
        }
    }

    private func triggerGravityReversal() {
        gravityEnds = currentTimeSnapshot + GameConstants.gravityReversalDuration
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
        viewModel.registerCollision()
        viewModel.finalizeScore()
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

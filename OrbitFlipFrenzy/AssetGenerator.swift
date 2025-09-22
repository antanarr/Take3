import Foundation
import SpriteKit
import UIKit

public protocol AssetGenerating {
    func makeBackground(size: CGSize) -> SKSpriteNode
    func makePlayerNode() -> SKShapeNode
    func makeRingNode(radius: CGFloat, lineWidth: CGFloat, color: UIColor, glow: CGFloat) -> SKShapeNode
    func makeObstacleNode(size: CGSize) -> SKShapeNode
    func makePowerUpNode(of type: PowerUpType) -> SKShapeNode
    func makeButtonNode(text: String, size: CGSize) -> SKSpriteNode
    func makeParticleTexture(radius: CGFloat, color: UIColor) -> SKTexture
}

public final class AssetGenerator: AssetGenerating {
    private let buttonFont = UIFont(name: "Orbitron-Bold", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold)

    public init() {}

    public func makeBackground(size: CGSize) -> SKSpriteNode {
        let texture = gradientTexture(size: size, colors: [GamePalette.deepNavy, GamePalette.royalBlue])
        let node = SKSpriteNode(texture: texture)
        node.zPosition = -10
        return node
    }

    public func makePlayerNode() -> SKShapeNode {
        let radius: CGFloat = 18
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor = GamePalette.neonMagenta
        node.strokeColor = GamePalette.cyan
        node.lineWidth = 4
        node.glowWidth = 8
        node.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        node.physicsBody?.isDynamic = true
        node.physicsBody?.allowsRotation = false
        node.physicsBody?.categoryBitMask = PhysicsCategory.player
        node.physicsBody?.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.powerUp
        node.physicsBody?.collisionBitMask = 0
        node.name = "player"

        if let trailTexture = makeParticleTexture(radius: 4, color: GamePalette.neonMagenta) {
            let emitter = SKEmitterNode()
            emitter.particleTexture = trailTexture
            emitter.particleBirthRate = GameConstants.particleBirthRate
            emitter.particleLifetime = GameConstants.particleLifetime
            emitter.particleAlpha = 0.8
            emitter.particleSpeed = 50
            emitter.particleColorBlendFactor = 1
            emitter.targetNode = node
            emitter.particleColor = GamePalette.neonMagenta
            emitter.position = .zero
            emitter.zPosition = -1
            node.addChild(emitter)
        }

        return node
    }

    public func makeRingNode(radius: CGFloat, lineWidth: CGFloat, color: UIColor, glow: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.lineWidth = lineWidth
        node.strokeColor = color
        node.fillColor = .clear
        node.glowWidth = glow
        node.alpha = 0.9
        return node
    }

    public func makeObstacleNode(size: CGSize) -> SKShapeNode {
        let path = UIBezierPath()
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        path.move(to: CGPoint(x: -halfWidth, y: -halfHeight))
        path.addLine(to: CGPoint(x: halfWidth, y: -halfHeight))
        path.addLine(to: CGPoint(x: 0, y: halfHeight))
        path.close()
        let node = SKShapeNode(path: path.cgPath)
        node.fillColor = GamePalette.solarGold
        node.strokeColor = GamePalette.cyan
        node.lineWidth = 2
        node.glowWidth = 4
        node.physicsBody = SKPhysicsBody(polygonFrom: path.cgPath)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = PhysicsCategory.obstacle
        node.physicsBody?.contactTestBitMask = PhysicsCategory.player
        node.physicsBody?.collisionBitMask = 0
        node.name = "obstacle"
        return node
    }

    public func makePowerUpNode(of type: PowerUpType) -> SKShapeNode {
        let node: SKShapeNode
        switch type {
        case .shield:
            node = SKShapeNode(circleOfRadius: 20)
            node.strokeColor = GamePalette.cyan
            node.fillColor = GamePalette.cyan.withAlphaComponent(0.3)
        case .slowMo:
            let rect = CGRect(x: -18, y: -18, width: 36, height: 36)
            node = SKShapeNode(rectOf: rect.size, cornerRadius: 10)
            node.fillColor = GamePalette.solarGold.withAlphaComponent(0.3)
            node.strokeColor = GamePalette.solarGold
        case .magnet:
            let path = UIBezierPath(arcCenter: .zero, radius: 20, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
            node = SKShapeNode(path: path.cgPath)
            node.fillColor = GamePalette.neonMagenta.withAlphaComponent(0.3)
            node.strokeColor = GamePalette.neonMagenta
        }
        node.lineWidth = 4
        node.glowWidth = 6
        node.name = "powerup"
        node.alpha = 0.85
        node.physicsBody = SKPhysicsBody(circleOfRadius: 20)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = PhysicsCategory.powerUp
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.contactTestBitMask = PhysicsCategory.player

        let aura = SKEmitterNode()
        aura.particleTexture = makeParticleTexture(radius: 6, color: node.strokeColor) ?? SKTexture()
        aura.particleBirthRate = 25
        aura.particleLifetime = 1.0
        aura.particleAlphaSpeed = -0.8
        aura.particleScale = 0.4
        aura.particleScaleSpeed = 0.2
        aura.particleColor = node.strokeColor
        aura.particleSpeed = 10
        aura.targetNode = node
        node.addChild(aura)
        return node
    }

    public func makeButtonNode(text: String, size: CGSize) -> SKSpriteNode {
        let texture = gradientTexture(size: size, colors: [GamePalette.neonMagenta, GamePalette.cyan])
        let node = SKSpriteNode(texture: texture)
        node.size = size
        node.colorBlendFactor = 0
        node.name = text

        let label = SKLabelNode(text: text)
        label.fontName = buttonFont.fontName
        label.fontSize = 20
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.fontColor = .white
        label.name = "label"
        node.addChild(label)

        let pressedTexture = gradientTexture(size: size, colors: [GamePalette.cyan, GamePalette.royalBlue])
        node.userData = ["pressedTexture": pressedTexture, "originalTexture": texture]
        return node
    }

    public func makeParticleTexture(radius: CGFloat, color: UIColor) -> SKTexture? {
        let size = CGSize(width: radius * 2 + 2, height: radius * 2 + 2)
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        let rect = CGRect(origin: .zero, size: size)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image.map(SKTexture.init)
    }

    private func gradientTexture(size: CGSize, colors: [UIColor]) -> SKTexture {
        let width = Int(size.width)
        let height = Int(size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return SKTexture()
        }
        let gradientColors = colors.map { $0.cgColor } as CFArray
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: nil) else {
            return SKTexture()
        }
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
        guard let image = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }
}

public extension SKSpriteNode {
    func setPressed(_ pressed: Bool) {
        guard let pressedTexture = userData?["pressedTexture"] as? SKTexture else { return }
        if pressed {
            userData?["originalTexture"] = self.texture
            self.texture = pressedTexture
        } else if let original = userData?["originalTexture"] as? SKTexture {
            self.texture = original
        }
    }
}

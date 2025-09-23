import Foundation
import SpriteKit
import UIKit


public enum BadgeIcon {
    case trophy
    case gems
    case timer
    case streak
=======
public enum InterfaceIcon {
    case play
    case share
    case retry
    case home
    case `continue`
    case streak
    case trophy
    case level
    case power
    case alert


public protocol AssetGenerating {
    func makeBackground(size: CGSize) -> SKSpriteNode
    func makePlayerNode() -> SKShapeNode
    func makeRingNode(radius: CGFloat, lineWidth: CGFloat, color: UIColor, glow: CGFloat) -> SKShapeNode
    func makeObstacleNode(size: CGSize) -> SKShapeNode
    func makePowerUpNode(of type: PowerUpType) -> SKShapeNode

    func makeButtonNode(text: String, size: CGSize) -> SKSpriteNode

    func makeMonetizationButton(title: String, subtitle: String, icon: String) -> SKSpriteNode
    func makeGemIcon(radius: CGFloat) -> SKShapeNode

    func makeBadgeNode(title: String, subtitle: String, size: CGSize, icon: BadgeIcon?) -> SKSpriteNode
    func makeLogoNode(size: CGSize) -> SKSpriteNode
    func makeAppIconImage(size: CGSize) -> UIImage
    func makeParticleTexture(radius: CGFloat, color: UIColor) -> SKTexture
    func makeHUDStatNode(title: String, value: String, size: CGSize, icon: BadgeIcon?, accent: UIColor) -> HUDStatNode
    func makeEventBanner(size: CGSize) -> EventBannerNode
    func makeGhostNode(size: CGSize) -> SKNode
    func makeButtonNode(text: String, size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode
    func makeParticleTexture(radius: CGFloat, color: UIColor) -> SKTexture
    func makeLogoNode(size: CGSize) -> SKSpriteNode
    func makeAppIconImage(size: CGSize) -> UIImage
    func makeBadgeNode(title: String, subtitle: String, size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode
    func makeGhostNode(radius: CGFloat) -> SKShapeNode
    func makeHUDStatNode(title: String, value: String, size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode
    func makeEventBanner(size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode

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

    public func makeButtonNode(text: String, size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode {
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

        if let icon {
            let iconDiameter = size.height * 0.5
            let iconNode = SKSpriteNode(texture: iconTexture(for: icon, diameter: iconDiameter))
            iconNode.size = CGSize(width: iconDiameter, height: iconDiameter)
            iconNode.position = CGPoint(x: -size.width * 0.3, y: 0)
            iconNode.alpha = 0.95
            iconNode.name = "icon"
            node.addChild(iconNode)

            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: iconNode.position.x + iconDiameter * 0.75, y: 0)
        }

        let pressedTexture = gradientTexture(size: size, colors: [GamePalette.cyan, GamePalette.royalBlue])
        node.userData = ["pressedTexture": pressedTexture, "originalTexture": texture]
        return node
    }

    public func makeMonetizationButton(title: String, subtitle: String, icon: String) -> SKSpriteNode {
        let size = CGSize(width: 220, height: 70)
        let baseTexture = gradientTexture(size: size, colors: [GamePalette.solarGold, GamePalette.neonMagenta])
        let pressedTexture = gradientTexture(size: size, colors: [GamePalette.neonMagenta, GamePalette.royalBlue])
        let node = SKSpriteNode(texture: baseTexture)
        node.size = size
        node.name = "monetizationButton"
        node.userData = ["pressedTexture": pressedTexture, "originalTexture": baseTexture]

        let iconNode = SKLabelNode(fontNamed: "SFProRounded-Bold")
        iconNode.text = icon
        iconNode.fontSize = 30
        iconNode.fontColor = .white
        iconNode.verticalAlignmentMode = .center
        iconNode.horizontalAlignmentMode = .center
        iconNode.position = CGPoint(x: -size.width * 0.35, y: 0)
        iconNode.name = "icon"
        node.addChild(iconNode)

        let titleLabel = SKLabelNode(fontNamed: "Orbitron-Bold")
        titleLabel.text = title
        titleLabel.fontSize = 18
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -size.width * 0.15, y: 12)
        titleLabel.name = "title"
        node.addChild(titleLabel)

        let subtitleLabel = SKLabelNode(fontNamed: "SFProRounded-Regular")
        subtitleLabel.text = subtitle
        subtitleLabel.fontSize = 12
        subtitleLabel.fontColor = UIColor.white.withAlphaComponent(0.85)
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.horizontalAlignmentMode = .left
        subtitleLabel.position = CGPoint(x: -size.width * 0.15, y: -14)
        subtitleLabel.name = "subtitle"
        node.addChild(subtitleLabel)

        let frame = SKShapeNode(rectOf: CGSize(width: size.width - 6, height: size.height - 6), cornerRadius: 28)
        frame.lineWidth = 2
        frame.strokeColor = UIColor.white.withAlphaComponent(0.35)
        frame.fillColor = .clear
        frame.zPosition = -1
        node.addChild(frame)

        return node
    }

    public func makeGemIcon(radius: CGFloat) -> SKShapeNode {
        let path = UIBezierPath()
        let width = radius * 1.2
        path.move(to: CGPoint(x: 0, y: radius))
        path.addLine(to: CGPoint(x: width, y: 0.0))
        path.addLine(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: -width, y: 0.0))
        path.close()
        let node = SKShapeNode(path: path.cgPath)
        node.fillColor = GamePalette.solarGold
        node.strokeColor = UIColor.white.withAlphaComponent(0.9)
        node.lineWidth = 2
        node.glowWidth = 4

        let facet = SKShapeNode(rectOf: CGSize(width: width * 1.2, height: radius * 0.4), cornerRadius: radius * 0.15)
        facet.fillColor = UIColor.white.withAlphaComponent(0.35)
        facet.strokeColor = UIColor.white.withAlphaComponent(0.0)
        facet.position = CGPoint(x: 0, y: radius * 0.25)
        facet.zPosition = 1
        node.addChild(facet)

        return node
    public func makeBadgeNode(title: String, subtitle: String, size: CGSize, icon: BadgeIcon?) -> SKSpriteNode {
        let badge = SKSpriteNode(color: .clear, size: size)
        badge.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        let texture = gradientTexture(size: size, colors: [GamePalette.royalBlue.withAlphaComponent(0.85), GamePalette.deepNavy])
        let background = SKSpriteNode(texture: texture)
        background.size = size
        background.alpha = 0.95
        background.zPosition = -2
        badge.addChild(background)

        let border = SKShapeNode(rectOf: size, cornerRadius: size.height * 0.35)
        border.strokeColor = GamePalette.cyan
        border.fillColor = .clear
        border.lineWidth = 2
        border.alpha = 0.9
        border.zPosition = -1
        badge.addChild(border)

        let titleLabel = SKLabelNode(fontNamed: "Orbitron-Bold")
        titleLabel.fontSize = min(22, size.height * 0.32)
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.text = title
        titleLabel.name = "title"

        let subtitleLabel = SKLabelNode(fontNamed: "SFProRounded-Regular")
        subtitleLabel.fontSize = min(15, size.height * 0.22)
        subtitleLabel.fontColor = UIColor.white.withAlphaComponent(0.75)
        subtitleLabel.horizontalAlignmentMode = .left
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.text = subtitle
        subtitleLabel.name = "subtitle"

        let inset = size.width * 0.12
        var titleX = -size.width * 0.5 + inset

        if let icon {
            let iconDiameter = size.height * 0.55
            let iconNode = makeBadgeIconNode(icon: icon, diameter: iconDiameter)
            iconNode.position = CGPoint(x: -size.width * 0.5 + iconDiameter / 2 + inset * 0.2, y: 0)
            badge.addChild(iconNode)
            titleX = iconNode.position.x + iconDiameter / 2 + inset * 0.35
        }

        titleLabel.position = CGPoint(x: titleX, y: size.height * 0.18)
        subtitleLabel.position = CGPoint(x: titleX, y: -size.height * 0.22)
        badge.addChild(titleLabel)
        badge.addChild(subtitleLabel)

        return badge
    }

    public func makeHUDStatNode(title: String,
                                value: String,
                                size: CGSize,
                                icon: BadgeIcon?,
                                accent: UIColor) -> HUDStatNode {
        let texture = gradientTexture(size: size, colors: [GamePalette.deepNavy.withAlphaComponent(0.85), GamePalette.royalBlue])
        let iconNode = icon.map { makeBadgeIconNode(icon: $0, diameter: size.height * 0.58) }
        return HUDStatNode(size: size,
                           backgroundTexture: texture,
                           title: title,
                           value: value,
                           icon: iconNode,
                           accentColor: accent)
    }

    public func makeEventBanner(size: CGSize) -> EventBannerNode {
        let texture = gradientTexture(size: size, colors: [GamePalette.deepNavy.withAlphaComponent(0.8), GamePalette.royalBlue])
        return EventBannerNode(size: size, backgroundTexture: texture)
    }

    public func makeGhostNode(size: CGSize) -> SKNode {
        let radius = min(size.width, size.height) / 2
        let container = SKNode()
        container.name = "ghost"

        let outer = SKShapeNode(circleOfRadius: radius)
        outer.fillColor = GamePalette.solarGold.withAlphaComponent(0.16)
        outer.strokeColor = GamePalette.solarGold
        outer.lineWidth = 2
        outer.glowWidth = 6
        outer.alpha = 0.4
        container.addChild(outer)

        let inner = SKShapeNode(circleOfRadius: radius * 0.55)
        inner.fillColor = GamePalette.neonMagenta.withAlphaComponent(0.25)
        inner.strokeColor = GamePalette.cyan
        inner.lineWidth = 1.5
        inner.alpha = 0.6
        container.addChild(inner)

        let trail = SKEmitterNode()
        trail.particleTexture = makeParticleTexture(radius: 4, color: GamePalette.solarGold) ?? SKTexture()
        trail.particleBirthRate = 36
        trail.particleLifetime = 1.1
        trail.particleLifetimeRange = 0.3
        trail.particleAlpha = 0.6
        trail.particleAlphaSpeed = -0.9
        trail.particleSpeed = 18
        trail.particleSpeedRange = 8
        trail.particlePositionRange = CGVector(dx: radius * 0.4, dy: radius * 0.4)
        trail.emissionAngleRange = .pi * 2
        trail.zPosition = -1
        container.addChild(trail)

        return container
    }

    public func makeLogoNode(size: CGSize) -> SKSpriteNode {
        let logo = SKSpriteNode(color: .clear, size: size)
        logo.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        let texture = gradientTexture(size: size, colors: [GamePalette.deepNavy, GamePalette.royalBlue])
        let background = SKSpriteNode(texture: texture)
        background.size = size
        background.zPosition = -1
        background.alpha = 0.95
        logo.addChild(background)

        let outline = SKShapeNode(rectOf: size, cornerRadius: size.height * 0.45)
        outline.lineWidth = 3
        outline.strokeColor = GamePalette.cyan
        outline.fillColor = UIColor.white.withAlphaComponent(0.08)
        outline.zPosition = 0
        logo.addChild(outline)

        let titleLabel = SKLabelNode(fontNamed: "Orbitron-Bold")
        titleLabel.text = "Orbit Flip"
        titleLabel.fontColor = GamePalette.solarGold
        titleLabel.fontSize = min(42, size.height * 0.6)
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: size.height * 0.12)
        logo.addChild(titleLabel)

        let subtitleLabel = SKLabelNode(fontNamed: "Orbitron-Bold")
        subtitleLabel.text = "Frenzy"
        subtitleLabel.fontColor = GamePalette.neonMagenta
        subtitleLabel.fontSize = min(40, size.height * 0.52)
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.horizontalAlignmentMode = .center
        subtitleLabel.position = CGPoint(x: 0, y: -size.height * 0.2)
        logo.addChild(subtitleLabel)

        let orbit = SKShapeNode(circleOfRadius: size.width * 0.45)
        orbit.strokeColor = GamePalette.cyan.withAlphaComponent(0.6)
        orbit.lineWidth = 2
        orbit.alpha = 0.6
        orbit.zPosition = -0.5
        logo.addChild(orbit)

        let accent = SKShapeNode(circleOfRadius: size.width * 0.08)
        accent.fillColor = GamePalette.neonMagenta
        accent.strokeColor = GamePalette.cyan
        accent.lineWidth = 2
        accent.position = CGPoint(x: size.width * 0.32, y: size.height * 0.18)
        accent.zPosition = 1
        logo.addChild(accent)

        return logo
    }

    public func makeAppIconImage(size: CGSize) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return UIImage()
        }

        let colors = [GamePalette.deepNavy.cgColor, GamePalette.royalBlue.cgColor, GamePalette.neonMagenta.cgColor] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.65, 1]) {
            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: rect.width, y: rect.height),
                                       options: [])
        } else {
            context.setFillColor(GamePalette.deepNavy.cgColor)
            context.fill(rect)
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radii: [CGFloat] = [0.32, 0.48, 0.64]
        for (index, scale) in radii.enumerated() {
            let radius = min(rect.width, rect.height) * scale * 0.5
            context.setStrokeColor((index % 2 == 0 ? GamePalette.cyan : GamePalette.neonMagenta).withAlphaComponent(0.85).cgColor)
            context.setLineWidth(max(4, rect.width * 0.04))
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: false)
            context.strokePath()
        }

        let podRect = CGRect(x: center.x - rect.width * 0.12,
                             y: center.y - rect.width * 0.12,
                             width: rect.width * 0.24,
                             height: rect.width * 0.24)
        context.setFillColor(GamePalette.neonMagenta.cgColor)
        context.fillEllipse(in: podRect)
        context.setStrokeColor(GamePalette.cyan.cgColor)
        context.setLineWidth(max(3, rect.width * 0.03))
        context.strokeEllipse(in: podRect.insetBy(dx: rect.width * 0.01, dy: rect.width * 0.01))

        let trailRect = CGRect(x: center.x - rect.width * 0.04,
                               y: podRect.minY - rect.height * 0.22,
                               width: rect.width * 0.08,
                               height: rect.height * 0.26)
        let trailPath = UIBezierPath(roundedRect: trailRect, cornerRadius: rect.width * 0.04)
        GamePalette.neonMagenta.withAlphaComponent(0.55).setFill()
        trailPath.fill()

        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
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

    public func makeLogoNode(size: CGSize) -> SKSpriteNode {
        let image = logoImage(size: size)
        let texture = SKTexture(image: image)
        let node = SKSpriteNode(texture: texture)
        node.size = size
        node.name = "logo"
        return node
    }

    public func makeAppIconImage(size: CGSize) -> UIImage {
        let dimension = max(size.width, size.height)
        let squareSize = CGSize(width: dimension, height: dimension)
        UIGraphicsBeginImageContextWithOptions(squareSize, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return UIImage()
        }

        let rect = CGRect(origin: .zero, size: squareSize)
        drawRoundedGradient(in: context,
                            rect: rect,
                            colors: [GamePalette.deepNavy.cgColor, GamePalette.royalBlue.cgColor],
                            cornerRadius: dimension * 0.22)

        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)

        // Orbit rings
        let radii: [CGFloat] = [dimension * 0.28, dimension * 0.42]
        for (index, radius) in radii.enumerated() {
            let alpha = 0.5 + (CGFloat(index) * 0.25)
            context.setStrokeColor(GamePalette.cyan.withAlphaComponent(alpha).cgColor)
            context.setLineWidth(dimension * 0.035)
            context.addEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
            context.strokePath()
        }

        // Player core
        context.setFillColor(GamePalette.neonMagenta.cgColor)
        let coreRadius = dimension * 0.16
        context.addEllipse(in: CGRect(x: -coreRadius, y: -coreRadius, width: coreRadius * 2, height: coreRadius * 2))
        context.fillPath()

        // Trailing comet arc
        context.setStrokeColor(GamePalette.solarGold.cgColor)
        context.setLineWidth(dimension * 0.05)
        context.addArc(center: CGPoint.zero,
                       radius: dimension * 0.46,
                       startAngle: CGFloat(Double.pi * 0.15),
                       endAngle: CGFloat(Double.pi * 1.1),
                       clockwise: false)
        context.strokePath()

        context.restoreGState()

        // Title text stripe
        let titleRect = CGRect(x: rect.width * 0.18, y: rect.height * 0.15, width: rect.width * 0.64, height: rect.height * 0.22)
        let titlePath = UIBezierPath(roundedRect: titleRect, cornerRadius: titleRect.height / 2)
        GamePalette.neonMagenta.withAlphaComponent(0.6).setFill()
        titlePath.fill()

        let titleStyle = NSMutableParagraphStyle()
        titleStyle.alignment = .center
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Orbitron-Bold", size: dimension * 0.13) ?? UIFont.systemFont(ofSize: dimension * 0.13, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: titleStyle
        ]
        let titleString = NSAttributedString(string: "OFF", attributes: titleAttributes)
        titleString.draw(in: titleRect)

        let icon = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return icon
    }

    public func makeBadgeNode(title: String, subtitle: String, size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode {
        let cornerRadius = size.height / 2
        let texture = roundedTexture(size: size,
                                     colors: [GamePalette.deepNavy.withAlphaComponent(0.85), GamePalette.royalBlue.withAlphaComponent(0.85)],
                                     cornerRadius: cornerRadius)
        let node = SKSpriteNode(texture: texture)
        node.size = size
        node.name = "badge"

        let padding: CGFloat = 24
        var textOriginX = -size.width / 2 + padding

        if let icon {
            let iconDiameter = size.height * 0.55
            let iconNode = SKSpriteNode(texture: iconTexture(for: icon, diameter: iconDiameter))
            iconNode.size = CGSize(width: iconDiameter, height: iconDiameter)
            iconNode.position = CGPoint(x: textOriginX + iconDiameter / 2, y: 0)
            iconNode.alpha = 0.95
            node.addChild(iconNode)
            textOriginX = iconNode.position.x + iconDiameter / 2 + 12
        }

        let titleLabel = SKLabelNode(text: title)
        titleLabel.fontName = buttonFont.fontName
        titleLabel.fontSize = 20
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: textOriginX, y: size.height * 0.18)
        titleLabel.name = "badge_title"
        node.addChild(titleLabel)

        let subtitleLabel = SKLabelNode(text: subtitle)
        subtitleLabel.fontName = "SFProRounded-Bold"
        subtitleLabel.fontSize = 14
        subtitleLabel.fontColor = UIColor.white.withAlphaComponent(0.7)
        subtitleLabel.horizontalAlignmentMode = .left
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.position = CGPoint(x: textOriginX, y: -size.height * 0.18)
        subtitleLabel.name = "badge_subtitle"
        node.addChild(subtitleLabel)

        return node
    }

    public func makeGhostNode(radius: CGFloat) -> SKShapeNode {
        let ghost = SKShapeNode(circleOfRadius: radius)
        ghost.fillColor = GamePalette.solarGold.withAlphaComponent(0.18)
        ghost.strokeColor = GamePalette.solarGold.withAlphaComponent(0.85)
        ghost.lineWidth = 3
        ghost.glowWidth = 9
        ghost.alpha = 0.45
        ghost.name = "ghost"

        let innerCore = SKShapeNode(circleOfRadius: radius * 0.48)
        innerCore.fillColor = GamePalette.solarGold.withAlphaComponent(0.75)
        innerCore.strokeColor = UIColor.white.withAlphaComponent(0.5)
        innerCore.lineWidth = 1.5
        innerCore.alpha = 0.9
        innerCore.zPosition = 1
        ghost.addChild(innerCore)

        let orbitRect = CGRect(x: -radius * 1.05, y: -radius * 0.3, width: radius * 2.1, height: radius * 1.4)
        let orbitPath = UIBezierPath(ovalIn: orbitRect)
        let orbit = SKShapeNode(path: orbitPath.cgPath)
        orbit.strokeColor = GamePalette.cyan.withAlphaComponent(0.7)
        orbit.lineWidth = 2
        orbit.glowWidth = 6
        orbit.fillColor = .clear
        orbit.alpha = 0.6
        orbit.zPosition = -1
        ghost.addChild(orbit)

        let arrowPath = UIBezierPath()
        arrowPath.move(to: CGPoint(x: radius * 0.65, y: 0))
        arrowPath.addLine(to: CGPoint(x: radius * 0.95, y: radius * 0.22))
        arrowPath.addLine(to: CGPoint(x: radius * 0.95, y: -radius * 0.22))
        arrowPath.close()
        let arrow = SKShapeNode(path: arrowPath.cgPath)
        arrow.fillColor = GamePalette.cyan
        arrow.strokeColor = UIColor.white.withAlphaComponent(0.4)
        arrow.lineWidth = 1
        arrow.alpha = 0.8
        arrow.zPosition = 2
        ghost.addChild(arrow)

        return ghost
    }

    public func makeHUDStatNode(title: String, value: String, size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode {
        let cornerRadius = size.height / 2
        let texture = roundedTexture(size: size,
                                     colors: [GamePalette.deepNavy.withAlphaComponent(0.82), GamePalette.royalBlue.withAlphaComponent(0.82)],
                                     cornerRadius: cornerRadius)
        let node = SKSpriteNode(texture: texture)
        node.size = size
        node.name = "hud_stat"

        var contentStartX = -size.width / 2 + 20

        if let icon {
            let iconDiameter = size.height * 0.6
            let iconNode = SKSpriteNode(texture: iconTexture(for: icon, diameter: iconDiameter))
            iconNode.size = CGSize(width: iconDiameter, height: iconDiameter)
            iconNode.position = CGPoint(x: contentStartX + iconDiameter / 2, y: 0)
            iconNode.alpha = 0.95
            iconNode.name = "icon"
            node.addChild(iconNode)
            contentStartX = iconNode.position.x + iconDiameter / 2 + 12
        }

        let titleLabel = SKLabelNode(text: title.uppercased())
        titleLabel.fontName = "SFProRounded-Bold"
        titleLabel.fontSize = size.height * 0.28
        titleLabel.fontColor = UIColor.white.withAlphaComponent(0.7)
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .top
        titleLabel.position = CGPoint(x: contentStartX, y: size.height * 0.25)
        titleLabel.name = "hud_title"
        node.addChild(titleLabel)

        let valueLabel = SKLabelNode(text: value)
        valueLabel.fontName = "Orbitron-Bold"
        valueLabel.fontSize = size.height * 0.42
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .left
        valueLabel.verticalAlignmentMode = .bottom
        valueLabel.position = CGPoint(x: contentStartX, y: -size.height * 0.2)
        valueLabel.name = "hud_value"
        node.addChild(valueLabel)

        return node
    }

    public func makeEventBanner(size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode {
        let cornerRadius = size.height / 2
        let texture = roundedTexture(size: size,
                                     colors: [GamePalette.neonMagenta.withAlphaComponent(0.85), GamePalette.cyan.withAlphaComponent(0.85)],
                                     cornerRadius: cornerRadius)
        let node = SKSpriteNode(texture: texture)
        node.size = size
        node.name = "event_banner"
        node.alpha = 0

        var contentStartX = -size.width / 2 + 20
        if let icon {
            let iconDiameter = size.height * 0.6
            let iconNode = SKSpriteNode(texture: iconTexture(for: icon, diameter: iconDiameter))
            iconNode.size = CGSize(width: iconDiameter, height: iconDiameter)
            iconNode.position = CGPoint(x: contentStartX + iconDiameter / 2, y: 0)
            iconNode.alpha = 0.95
            iconNode.name = "icon"
            node.addChild(iconNode)
            contentStartX = iconNode.position.x + iconDiameter / 2 + 12
        }

        let label = SKLabelNode(text: "")
        label.fontName = "Orbitron-Bold"
        label.fontSize = size.height * 0.42
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: contentStartX, y: -size.height * 0.04)
        if icon == nil {
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: -size.height * 0.04)
        }
        label.name = "banner_label"
        node.addChild(label)

        return node
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

    private func roundedTexture(size: CGSize, colors: [UIColor], cornerRadius: CGFloat) -> SKTexture {
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return SKTexture() }
        drawRoundedGradient(in: context,
                            rect: CGRect(origin: .zero, size: size),
                            colors: colors.map { $0.cgColor },
                            cornerRadius: cornerRadius)
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return SKTexture()
        }
        UIGraphicsEndImageContext()
        return SKTexture(image: image)
    }

    private func drawRoundedGradient(in context: CGContext, rect: CGRect, colors: [CGColor], cornerRadius: CGFloat) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil) else { return }
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: rect.minX, y: rect.minY),
                                   end: CGPoint(x: rect.maxX, y: rect.maxY),
                                   options: [])
        context.restoreGState()
    }

    private func iconTexture(for icon: InterfaceIcon, diameter: CGFloat) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return SKTexture()
        }
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let strokeWidth = max(2, diameter * 0.12)
        context.setLineWidth(strokeWidth)

        switch icon {
        case .play:
            context.setFillColor(GamePalette.solarGold.cgColor)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: -diameter * 0.2, y: diameter * 0.28))
            path.addLine(to: CGPoint(x: diameter * 0.35, y: 0))
            path.addLine(to: CGPoint(x: -diameter * 0.2, y: -diameter * 0.28))
            path.close()
            context.addPath(path.cgPath)
            context.fillPath()
        case .share:
            context.setStrokeColor(GamePalette.cyan.cgColor)
            let arrow = UIBezierPath()
            arrow.move(to: CGPoint(x: 0, y: diameter * 0.4))
            arrow.addLine(to: CGPoint(x: 0, y: -diameter * 0.15))
            arrow.move(to: CGPoint(x: -diameter * 0.18, y: diameter * 0.1))
            arrow.addLine(to: CGPoint(x: 0, y: -diameter * 0.15))
            arrow.addLine(to: CGPoint(x: diameter * 0.18, y: diameter * 0.1))
            context.addPath(arrow.cgPath)
            context.strokePath()

            context.setLineWidth(strokeWidth * 0.85)
            let tray = UIBezierPath()
            tray.move(to: CGPoint(x: -diameter * 0.3, y: -diameter * 0.25))
            tray.addLine(to: CGPoint(x: -diameter * 0.3, y: -diameter * 0.4))
            tray.addLine(to: CGPoint(x: diameter * 0.3, y: -diameter * 0.4))
            tray.addLine(to: CGPoint(x: diameter * 0.3, y: -diameter * 0.25))
            context.addPath(tray.cgPath)
            context.strokePath()
        case .retry:
            context.setStrokeColor(GamePalette.neonMagenta.cgColor)
            let circle = UIBezierPath(arcCenter: .zero,
                                      radius: diameter * 0.32,
                                      startAngle: CGFloat(Double.pi * 0.15),
                                      endAngle: CGFloat(Double.pi * 1.7),
                                      clockwise: true)
            context.addPath(circle.cgPath)
            context.strokePath()

            let arrow = UIBezierPath()
            arrow.move(to: CGPoint(x: -diameter * 0.12, y: diameter * 0.42))
            arrow.addLine(to: CGPoint(x: diameter * 0.12, y: diameter * 0.42))
            arrow.addLine(to: CGPoint(x: 0, y: diameter * 0.6))
            arrow.close()
            context.setFillColor(GamePalette.neonMagenta.cgColor)
            context.addPath(arrow.cgPath)
            context.fillPath()
        case .home:
            context.setStrokeColor(UIColor.white.cgColor)
            let house = UIBezierPath()
            house.move(to: CGPoint(x: -diameter * 0.35, y: -diameter * 0.1))
            house.addLine(to: CGPoint(x: 0, y: diameter * 0.4))
            house.addLine(to: CGPoint(x: diameter * 0.35, y: -diameter * 0.1))
            context.addPath(house.cgPath)
            context.strokePath()

            let door = UIBezierPath(roundedRect: CGRect(x: -diameter * 0.12,
                                                        y: -diameter * 0.35,
                                                        width: diameter * 0.24,
                                                        height: diameter * 0.32),
                                     cornerRadius: diameter * 0.08)
            context.addPath(door.cgPath)
            context.strokePath()
        case .continue:
            context.setFillColor(GamePalette.cyan.cgColor)
            let play = UIBezierPath()
            play.move(to: CGPoint(x: -diameter * 0.22, y: diameter * 0.28))
            play.addLine(to: CGPoint(x: diameter * 0.36, y: 0))
            play.addLine(to: CGPoint(x: -diameter * 0.22, y: -diameter * 0.28))
            play.close()
            context.addPath(play.cgPath)
            context.fillPath()

            context.setStrokeColor(GamePalette.solarGold.cgColor)
            context.setLineWidth(strokeWidth * 0.7)
            context.addArc(center: CGPoint(x: -diameter * 0.05, y: 0),
                           radius: diameter * 0.42,
                           startAngle: CGFloat(Double.pi * 0.2),
                           endAngle: CGFloat(Double.pi * 0.9),
                           clockwise: false)
            context.strokePath()
        case .streak:
            context.setFillColor(GamePalette.solarGold.cgColor)
            let flame = UIBezierPath()
            flame.move(to: CGPoint(x: 0, y: diameter * 0.5))
            flame.addCurve(to: CGPoint(x: -diameter * 0.22, y: 0),
                           controlPoint1: CGPoint(x: -diameter * 0.18, y: diameter * 0.32),
                           controlPoint2: CGPoint(x: -diameter * 0.35, y: diameter * 0.12))
            flame.addCurve(to: CGPoint(x: 0, y: -diameter * 0.5),
                           controlPoint1: CGPoint(x: -diameter * 0.05, y: -diameter * 0.1),
                           controlPoint2: CGPoint(x: -diameter * 0.02, y: -diameter * 0.45))
            flame.addCurve(to: CGPoint(x: diameter * 0.22, y: 0),
                           controlPoint1: CGPoint(x: diameter * 0.02, y: -diameter * 0.15),
                           controlPoint2: CGPoint(x: diameter * 0.35, y: diameter * 0.1))
            flame.close()
            context.addPath(flame.cgPath)
            context.fillPath()
        case .trophy:
            context.setStrokeColor(GamePalette.solarGold.cgColor)
            let cup = UIBezierPath()
            cup.move(to: CGPoint(x: -diameter * 0.35, y: diameter * 0.2))
            cup.addLine(to: CGPoint(x: -diameter * 0.25, y: diameter * 0.4))
            cup.addLine(to: CGPoint(x: diameter * 0.25, y: diameter * 0.4))
            cup.addLine(to: CGPoint(x: diameter * 0.35, y: diameter * 0.2))
            cup.addLine(to: CGPoint(x: diameter * 0.15, y: -diameter * 0.15))
            cup.addLine(to: CGPoint(x: diameter * 0.15, y: -diameter * 0.3))
            cup.addLine(to: CGPoint(x: -diameter * 0.15, y: -diameter * 0.3))
            cup.addLine(to: CGPoint(x: -diameter * 0.15, y: -diameter * 0.15))
            cup.close()
            context.addPath(cup.cgPath)
            context.strokePath()

            context.setLineWidth(strokeWidth * 0.8)
            context.move(to: CGPoint(x: -diameter * 0.45, y: diameter * 0.1))
            context.addLine(to: CGPoint(x: -diameter * 0.35, y: diameter * 0.2))
            context.move(to: CGPoint(x: diameter * 0.45, y: diameter * 0.1))
            context.addLine(to: CGPoint(x: diameter * 0.35, y: diameter * 0.2))
            context.strokePath()
        case .level:
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.85).cgColor)
            let pole = UIBezierPath()
            pole.move(to: CGPoint(x: -diameter * 0.25, y: -diameter * 0.45))
            pole.addLine(to: CGPoint(x: -diameter * 0.25, y: diameter * 0.45))
            context.addPath(pole.cgPath)
            context.strokePath()

            context.setFillColor(GamePalette.cyan.cgColor)
            let flag = UIBezierPath()
            flag.move(to: CGPoint(x: -diameter * 0.25, y: diameter * 0.35))
            flag.addLine(to: CGPoint(x: diameter * 0.25, y: diameter * 0.2))
            flag.addLine(to: CGPoint(x: -diameter * 0.25, y: diameter * 0.05))
            flag.close()
            context.addPath(flag.cgPath)
            context.fillPath()

            context.setFillColor(GamePalette.solarGold.cgColor)
            let baseWidth = diameter * 0.26
            let baseRect = CGRect(x: -diameter * 0.25 - baseWidth / 2,
                                  y: -diameter * 0.55,
                                  width: baseWidth,
                                  height: diameter * 0.2)
            let base = UIBezierPath(roundedRect: baseRect, cornerRadius: diameter * 0.04)
            context.addPath(base.cgPath)
            context.fillPath()
        case .power:
            context.setFillColor(GamePalette.neonMagenta.cgColor)
            let bolt = UIBezierPath()
            bolt.move(to: CGPoint(x: diameter * 0.2, y: diameter * 0.45))
            bolt.addLine(to: CGPoint(x: -diameter * 0.05, y: diameter * 0.1))
            bolt.addLine(to: CGPoint(x: diameter * 0.15, y: diameter * 0.1))
            bolt.addLine(to: CGPoint(x: -diameter * 0.2, y: -diameter * 0.45))
            bolt.addLine(to: CGPoint(x: diameter * 0.05, y: -diameter * 0.1))
            bolt.addLine(to: CGPoint(x: -diameter * 0.15, y: -diameter * 0.1))
            bolt.close()
            context.addPath(bolt.cgPath)
            context.fillPath()

            context.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
            context.setLineWidth(strokeWidth * 0.6)
            context.addPath(bolt.cgPath)
            context.strokePath()
        case .alert:
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(strokeWidth * 0.9)
            let exclamation = UIBezierPath()
            exclamation.move(to: CGPoint(x: 0, y: diameter * 0.4))
            exclamation.addLine(to: CGPoint(x: 0, y: -diameter * 0.1))
            context.addPath(exclamation.cgPath)
            context.strokePath()

            context.setFillColor(UIColor.white.cgColor)
            let dotRadius = diameter * 0.08
            context.addEllipse(in: CGRect(x: -dotRadius, y: -diameter * 0.35, width: dotRadius * 2, height: dotRadius * 2))
            context.fillPath()
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image.map(SKTexture.init) ?? SKTexture()
    }

    private func logoImage(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return UIImage()
        }

        drawRoundedGradient(in: context,
                            rect: CGRect(origin: .zero, size: size),
                            colors: [GamePalette.deepNavy.withAlphaComponent(0.9).cgColor, GamePalette.royalBlue.cgColor],
                            cornerRadius: size.height * 0.3)

        context.saveGState()
        context.translateBy(x: size.width / 2, y: size.height / 2)

        // Outer orbit arc
        context.setStrokeColor(GamePalette.cyan.cgColor)
        context.setLineWidth(size.height * 0.08)
        context.addArc(center: .zero,
                       radius: size.height * 0.38,
                       startAngle: CGFloat(-Double.pi * 0.7),
                       endAngle: CGFloat(Double.pi * 0.3),
                       clockwise: false)
        context.strokePath()

        // Inner orbit arc
        context.setStrokeColor(GamePalette.neonMagenta.cgColor)
        context.setLineWidth(size.height * 0.05)
        context.addArc(center: .zero,
                       radius: size.height * 0.22,
                       startAngle: CGFloat(-Double.pi * 0.2),
                       endAngle: CGFloat(Double.pi * 0.9),
                       clockwise: false)
        context.strokePath()

        // Spark particles
        let sparkRadius = size.height * 0.04
        let sparkPositions = [
            CGPoint(x: -size.width * 0.28, y: size.height * 0.18),
            CGPoint(x: size.width * 0.22, y: size.height * 0.24),
            CGPoint(x: size.width * 0.18, y: -size.height * 0.26)
        ]
        context.setFillColor(GamePalette.solarGold.cgColor)
        for point in sparkPositions {
            context.addEllipse(in: CGRect(x: point.x - sparkRadius,
                                          y: point.y - sparkRadius,
                                          width: sparkRadius * 2,
                                          height: sparkRadius * 2))
        }
        context.fillPath()

        // Player core
        context.setFillColor(GamePalette.neonMagenta.cgColor)
        let coreRadius = size.height * 0.14
        context.addEllipse(in: CGRect(x: -coreRadius, y: -coreRadius, width: coreRadius * 2, height: coreRadius * 2))
        context.fillPath()

        // Play arrow overlay
        context.setFillColor(GamePalette.solarGold.cgColor)
        let arrow = UIBezierPath()
        arrow.move(to: CGPoint(x: -coreRadius * 0.4, y: coreRadius * 0.65))
        arrow.addLine(to: CGPoint(x: coreRadius * 1.1, y: 0))
        arrow.addLine(to: CGPoint(x: -coreRadius * 0.4, y: -coreRadius * 0.65))
        arrow.close()
        context.addPath(arrow.cgPath)
        context.fillPath()

        context.restoreGState()

        let titleStyle = NSMutableParagraphStyle()
        titleStyle.alignment = .center
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Orbitron-Bold", size: size.height * 0.26) ?? UIFont.systemFont(ofSize: size.height * 0.26, weight: .heavy),
            .foregroundColor: UIColor.white,
            .paragraphStyle: titleStyle
        ]
        let titleString = NSAttributedString(string: "Orbital", attributes: titleAttributes)
        let subtitleString = NSAttributedString(string: "Flip Frenzy",
                                                attributes: [
                                                    .font: UIFont(name: "SFProRounded-Bold", size: size.height * 0.16) ?? UIFont.systemFont(ofSize: size.height * 0.16, weight: .bold),
                                                    .foregroundColor: GamePalette.cyan,
                                                    .paragraphStyle: titleStyle
                                                ])
        let titleRect = CGRect(x: 0, y: size.height * 0.1, width: size.width, height: size.height * 0.36)
        titleString.draw(in: titleRect)
        let subtitleRect = CGRect(x: 0, y: size.height * 0.48, width: size.width, height: size.height * 0.24)
        subtitleString.draw(in: subtitleRect)

        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }
}

public final class HUDStatNode: SKNode {
    public let contentSize: CGSize

    private let background: SKSpriteNode
    private let highlightNode: SKShapeNode
    private let border: SKShapeNode
    private let valueLabel: SKLabelNode
    private var accentColor: UIColor
    private var isHighlightedState = false

    init(size: CGSize,
         backgroundTexture: SKTexture?,
         title: String,
         value: String,
         icon: SKNode?,
         accentColor: UIColor) {
        self.contentSize = size
        self.accentColor = accentColor

        if let texture = backgroundTexture {
            background = SKSpriteNode(texture: texture)
        } else {
            background = SKSpriteNode(color: GamePalette.deepNavy.withAlphaComponent(0.85), size: size)
        }
        background.size = size
        background.alpha = 0.9
        background.zPosition = -2

        let highlight = SKShapeNode(rectOf: size, cornerRadius: size.height * 0.45)
        highlight.fillColor = accentColor.withAlphaComponent(0.22)
        highlight.strokeColor = .clear
        highlight.alpha = 0
        highlight.zPosition = -1
        highlightNode = highlight

        border = SKShapeNode(rectOf: size, cornerRadius: size.height * 0.45)
        border.strokeColor = accentColor.withAlphaComponent(0.8)
        border.lineWidth = 2
        border.fillColor = UIColor.clear
        border.zPosition = 0

        let padding = size.width * 0.12
        var textX = -size.width / 2 + padding

        super.init()

        addChild(background)
        addChild(highlightNode)
        addChild(border)

        if let icon {
            let iconFrame = icon.calculateAccumulatedFrame()
            let iconWidth = iconFrame.width
            icon.zPosition = 1
            icon.position = CGPoint(x: textX + iconWidth / 2, y: 0)
            addChild(icon)
            textX = icon.position.x + iconWidth / 2 + padding * 0.4
        }

        let titleLabel = SKLabelNode(fontNamed: "SFProRounded-Regular")
        titleLabel.fontSize = min(14, size.height * 0.26)
        titleLabel.fontColor = UIColor.white.withAlphaComponent(0.7)
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.text = title.uppercased()
        titleLabel.position = CGPoint(x: textX, y: size.height * 0.18)
        titleLabel.zPosition = 1
        addChild(titleLabel)

        let valueNode = SKLabelNode(fontNamed: "Orbitron-Bold")
        valueNode.fontSize = min(26, size.height * 0.5)
        valueNode.fontColor = .white
        valueNode.horizontalAlignmentMode = .left
        valueNode.verticalAlignmentMode = .center
        valueNode.text = value
        valueNode.position = CGPoint(x: textX, y: -size.height * 0.18)
        valueNode.zPosition = 1
        addChild(valueNode)
        valueLabel = valueNode
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func updateValue(_ text: String) {
        valueLabel.text = text
    }

    public func setAccentColor(_ color: UIColor) {
        accentColor = color
        border.strokeColor = color.withAlphaComponent(0.85)
        highlightNode.fillColor = color.withAlphaComponent(0.22)
    }

    public func setHighlighted(_ highlighted: Bool) {
        guard highlighted != isHighlightedState else { return }
        isHighlightedState = highlighted
        let target = highlighted ? CGFloat(1.0) : 0.0
        highlightNode.removeAllActions()
        highlightNode.run(SKAction.fadeAlpha(to: target, duration: 0.2))
        valueLabel.fontColor = highlighted ? accentColor : .white
        if highlighted && action(forKey: "hudHighlightPulse") == nil {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.02, duration: 0.35),
                SKAction.scale(to: 1.0, duration: 0.35)
            ])
            run(SKAction.repeatForever(pulse), withKey: "hudHighlightPulse")
        } else if !highlighted {
            removeAction(forKey: "hudHighlightPulse")
            run(SKAction.scale(to: 1.0, duration: 0.2))
        }
    }
}

public final class EventBannerNode: SKNode {
    private let background: SKSpriteNode
    private let border: SKShapeNode
    private let accentBar: SKShapeNode
    private let glowNode: SKShapeNode
    private let label: SKLabelNode

    init(size: CGSize, backgroundTexture: SKTexture?) {
        if let texture = backgroundTexture {
            background = SKSpriteNode(texture: texture)
        } else {
            background = SKSpriteNode(color: GamePalette.deepNavy.withAlphaComponent(0.9), size: size)
        }
        background.size = size
        background.alpha = 0.9
        background.zPosition = -2

        glowNode = SKShapeNode(rectOf: size, cornerRadius: size.height * 0.48)
        glowNode.fillColor = GamePalette.solarGold.withAlphaComponent(0.22)
        glowNode.strokeColor = .clear
        glowNode.alpha = 0
        glowNode.zPosition = -1

        border = SKShapeNode(rectOf: size, cornerRadius: size.height * 0.48)
        border.lineWidth = 2
        border.strokeColor = GamePalette.solarGold
        border.fillColor = UIColor.clear
        border.zPosition = 0

        let accentWidth = max(6, size.width * 0.06)
        accentBar = SKShapeNode(rectOf: CGSize(width: accentWidth, height: size.height * 0.7), cornerRadius: accentWidth / 2)
        accentBar.fillColor = GamePalette.solarGold
        accentBar.strokeColor = .clear
        accentBar.position = CGPoint(x: -size.width * 0.42, y: 0)
        accentBar.zPosition = 1

        label = SKLabelNode(fontNamed: "Orbitron-Bold")
        label.fontSize = min(22, size.height * 0.46)
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 2

        super.init()

        addChild(background)
        addChild(glowNode)
        addChild(border)
        addChild(accentBar)
        addChild(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func present(message: String, accent: UIColor) {
        label.text = message
        accentBar.fillColor = accent
        border.strokeColor = accent
        glowNode.removeAllActions()
        glowNode.fillColor = accent.withAlphaComponent(0.28)
        glowNode.alpha = 1
        let glowFade = SKAction.fadeAlpha(to: 0, duration: 0.6)
        glowFade.timingMode = .easeOut
        glowNode.run(glowFade)

        removeAllActions()
        alpha = 0
        run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.wait(forDuration: 1.8),
            SKAction.fadeOut(withDuration: 0.3)
        ]))
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

private extension AssetGenerator {
    func makeBadgeIconNode(icon: BadgeIcon, diameter: CGFloat) -> SKNode {
        let container = SKNode()
        let size = CGSize(width: diameter, height: diameter)
        let background = SKShapeNode(circleOfRadius: diameter / 2)
        background.fillColor = GamePalette.solarGold.withAlphaComponent(0.2)
        background.strokeColor = GamePalette.solarGold
        background.lineWidth = 2
        container.addChild(background)

        let iconNode: SKShapeNode
        switch icon {
        case .trophy:
            let path = UIBezierPath()
            let w = size.width * 0.6
            let h = size.height * 0.55
            path.move(to: CGPoint(x: -w / 2, y: h / 2))
            path.addLine(to: CGPoint(x: w / 2, y: h / 2))
            path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.05))
            path.addLine(to: CGPoint(x: w * 0.2, y: -h * 0.25))
            path.addLine(to: CGPoint(x: -w * 0.2, y: -h * 0.25))
            path.addLine(to: CGPoint(x: -w * 0.4, y: h * 0.05))
            path.close()
            iconNode = SKShapeNode(path: path.cgPath)
            iconNode.fillColor = GamePalette.solarGold
            iconNode.strokeColor = GamePalette.cyan
            iconNode.lineWidth = 1.5
        case .gems:
            let path = UIBezierPath()
            let w = size.width * 0.6
            path.move(to: CGPoint(x: 0, y: w / 2))
            path.addLine(to: CGPoint(x: w / 2, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -w / 2))
            path.addLine(to: CGPoint(x: -w / 2, y: 0))
            path.close()
            iconNode = SKShapeNode(path: path.cgPath)
            iconNode.fillColor = GamePalette.cyan
            iconNode.strokeColor = GamePalette.neonMagenta
            iconNode.lineWidth = 1.5
        case .timer:
            let circle = SKShapeNode(circleOfRadius: size.width * 0.3)
            circle.fillColor = UIColor.clear
            circle.strokeColor = GamePalette.cyan
            circle.lineWidth = 2
            let hand = SKShapeNode(rectOf: CGSize(width: 2, height: size.width * 0.3))
            hand.position = CGPoint(x: 0, y: size.width * 0.15)
            hand.fillColor = GamePalette.neonMagenta
            hand.strokeColor = GamePalette.neonMagenta
            let top = SKShapeNode(rectOf: CGSize(width: size.width * 0.3, height: size.height * 0.1), cornerRadius: size.height * 0.05)
            top.position = CGPoint(x: 0, y: size.height * 0.32)
            top.fillColor = GamePalette.solarGold
            top.strokeColor = GamePalette.solarGold
            container.addChild(circle)
            container.addChild(hand)
            container.addChild(top)
            return container
        case .streak:
            let path = UIBezierPath()
            let h = size.height * 0.6
            path.move(to: CGPoint(x: -h / 2, y: -h / 2))
            path.addLine(to: CGPoint(x: 0, y: h / 2))
            path.addLine(to: CGPoint(x: h / 2, y: -h / 2))
            path.close()
            iconNode = SKShapeNode(path: path.cgPath)
            iconNode.fillColor = GamePalette.neonMagenta
            iconNode.strokeColor = GamePalette.cyan
            iconNode.lineWidth = 1.5
        }

        iconNode.position = .zero
        container.addChild(iconNode)
        return container
    }
}

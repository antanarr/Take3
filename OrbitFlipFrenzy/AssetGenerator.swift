import Foundation
import SpriteKit
import UIKit

public enum BadgeIcon {
    case trophy
    case gems
    case timer
    case streak
}

public protocol AssetGenerating {
    func makeBackground(size: CGSize) -> SKSpriteNode
    func makePlayerNode() -> SKShapeNode
    func makeRingNode(radius: CGFloat, lineWidth: CGFloat, color: UIColor, glow: CGFloat) -> SKShapeNode
    func makeObstacleNode(size: CGSize) -> SKShapeNode
    func makePowerUpNode(of type: PowerUpType) -> SKShapeNode
    func makeButtonNode(text: String, size: CGSize) -> SKSpriteNode
    func makeBadgeNode(title: String, subtitle: String, size: CGSize, icon: BadgeIcon?) -> SKSpriteNode
    func makeLogoNode(size: CGSize) -> SKSpriteNode
    func makeAppIconImage(size: CGSize) -> UIImage
    func makeParticleTexture(radius: CGFloat, color: UIColor) -> SKTexture
    func makeHUDStatNode(title: String, value: String, size: CGSize, icon: BadgeIcon?, accent: UIColor) -> HUDStatNode
    func makeEventBanner(size: CGSize) -> EventBannerNode
    func makeGhostNode(size: CGSize) -> SKNode
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

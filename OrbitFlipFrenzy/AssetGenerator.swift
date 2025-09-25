import Foundation
import SpriteKit
import UIKit

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
    case gems
    case timer
    case info
}

public protocol AssetGenerating: AnyObject {
    func makeBackground(size: CGSize) -> SKSpriteNode
    func makePlayerNode() -> SKShapeNode
    func makeRingNode(radius: CGFloat, lineWidth: CGFloat, color: UIColor, glow: CGFloat) -> SKShapeNode
    func makeObstacleNode(size: CGSize) -> SKShapeNode
    func makePowerUpNode(of type: PowerUpType) -> SKShapeNode

    func makeButtonNode(text: String, size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode
    func makeMonetizationButton(title: String, subtitle: String, icon: String) -> SKSpriteNode
    func makeGemIcon(radius: CGFloat) -> SKShapeNode
    func makeBadgeNode(title: String, subtitle: String, size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode
    func makeHUDStatNode(title: String, value: String, size: CGSize, icon: InterfaceIcon?, accent: UIColor) -> HUDStatNode
    func makeEventBanner(size: CGSize, icon: InterfaceIcon?) -> EventBannerNode
    func makeGhostNode(radius: CGFloat) -> SKNode

    func makeLogoNode(size: CGSize) -> SKSpriteNode
    func makeAppIconImage(size: CGSize) -> UIImage
    func makeParticleTexture(radius: CGFloat, color: UIColor) -> SKTexture?
}

public final class AssetGenerator: AssetGenerating {
    private let buttonFont = UIFont(name: "Orbitron-Bold", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold)

    public init() {}

    // MARK: Scene Elements

    public func makeBackground(size: CGSize) -> SKSpriteNode {
        let texture = gradientTexture(size: size, colors: [GamePalette.deepNavy, GamePalette.royalBlue])
        let node = SKSpriteNode(texture: texture)
        node.size = size
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
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.powerUp
        node.name = "player"

        if let texture = makeParticleTexture(radius: 4, color: GamePalette.neonMagenta) {
            let emitter = SKEmitterNode()
            emitter.particleTexture = texture
            emitter.particleBirthRate = GameConstants.particleBirthRate
            emitter.particleLifetime = GameConstants.particleLifetime
            emitter.particleAlpha = 0.7
            emitter.particleSpeed = 55
            emitter.particleColorBlendFactor = 1
            emitter.targetNode = node
            emitter.particleColor = GamePalette.neonMagenta
            emitter.zPosition = -1
            emitter.position = .zero
            node.addChild(emitter)
        }
        return node
    }

    public func makeRingNode(radius: CGFloat, lineWidth: CGFloat, color: UIColor, glow: CGFloat) -> SKShapeNode {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.lineWidth = lineWidth
        ring.strokeColor = color
        ring.glowWidth = glow
        ring.fillColor = .clear
        ring.alpha = 0.85
        return ring
    }

    public func makeObstacleNode(size: CGSize) -> SKShapeNode {
        let rect = CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2), size: size)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: size.width * 0.25)
        let node = SKShapeNode(path: path.cgPath)
        node.fillColor = GamePalette.solarGold
        node.strokeColor = GamePalette.neonMagenta
        node.lineWidth = 3
        node.glowWidth = 6
        node.physicsBody = SKPhysicsBody(polygonFrom: path.cgPath)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = PhysicsCategory.obstacle
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.contactTestBitMask = PhysicsCategory.player
        node.name = "obstacle"
        return node
    }

    public func makePowerUpNode(of type: PowerUpType) -> SKShapeNode {
        let node: SKShapeNode
        switch type {
        case .shield:
            node = SKShapeNode(circleOfRadius: 20)
            node.fillColor = GamePalette.cyan.withAlphaComponent(0.25)
            node.strokeColor = GamePalette.cyan
        case .slowMo:
            node = SKShapeNode(rectOf: CGSize(width: 42, height: 42), cornerRadius: 14)
            node.fillColor = GamePalette.solarGold.withAlphaComponent(0.25)
            node.strokeColor = GamePalette.solarGold
        case .magnet:
            let path = UIBezierPath()
            path.addArc(withCenter: .zero, radius: 20, startAngle: .pi, endAngle: 0, clockwise: true)
            path.addLine(to: CGPoint(x: 14, y: -18))
            path.addLine(to: CGPoint(x: 8, y: -18))
            path.addLine(to: CGPoint(x: 8, y: -10))
            path.addLine(to: CGPoint(x: -8, y: -10))
            path.addLine(to: CGPoint(x: -8, y: -18))
            path.addLine(to: CGPoint(x: -14, y: -18))
            path.close()
            node = SKShapeNode(path: path.cgPath)
            node.fillColor = GamePalette.neonMagenta.withAlphaComponent(0.25)
            node.strokeColor = GamePalette.neonMagenta
        }
        node.lineWidth = 4
        node.glowWidth = 7
        node.alpha = 0.9
        node.physicsBody = SKPhysicsBody(circleOfRadius: 20)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = PhysicsCategory.powerUp
        node.physicsBody?.contactTestBitMask = PhysicsCategory.player
        node.physicsBody?.collisionBitMask = 0
        node.name = "powerup"

        if let texture = makeParticleTexture(radius: 6, color: node.strokeColor) {
            let aura = SKEmitterNode()
            aura.particleTexture = texture
            aura.particleBirthRate = 28
            aura.particleLifetime = 1.0
            aura.particleAlphaSpeed = -0.8
            aura.particleScale = 0.45
            aura.particleScaleSpeed = 0.2
            aura.particleSpeed = 12
            aura.targetNode = node
            aura.zPosition = -1
            node.addChild(aura)
        }

        return node
    }

    // MARK: UI Components

    public func makeButtonNode(text: String, size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode {
        let base = gradientTexture(size: size, colors: [GamePalette.neonMagenta, GamePalette.cyan])
        let pressed = gradientTexture(size: size, colors: [GamePalette.cyan, GamePalette.royalBlue])
        let node = SKSpriteNode(texture: base)
        node.size = size
        node.name = "button"
        node.userData = [
            "originalTexture": base,
            "pressedTexture": pressed
        ]

        let label = SKLabelNode(text: text)
        label.fontName = buttonFont.fontName
        label.fontSize = 20
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = icon == nil ? .center : .left
        label.name = "label"

        if let icon {
            let diameter = size.height * 0.55
            let iconNode = SKSpriteNode(texture: iconTexture(for: icon, diameter: diameter))
            iconNode.size = CGSize(width: diameter, height: diameter)
            iconNode.position = CGPoint(x: -size.width * 0.32, y: 0)
            iconNode.name = "icon"
            node.addChild(iconNode)
            label.position = CGPoint(x: iconNode.position.x + diameter * 0.7, y: 0)
        }

        node.addChild(label)
        return node
    }

    public func makeMonetizationButton(title: String, subtitle: String, icon: String) -> SKSpriteNode {
        let size = CGSize(width: 220, height: 70)
        let base = gradientTexture(size: size, colors: [GamePalette.solarGold, GamePalette.neonMagenta])
        let pressed = gradientTexture(size: size, colors: [GamePalette.neonMagenta, GamePalette.royalBlue])
        let node = SKSpriteNode(texture: base)
        node.size = size
        node.userData = [
            "originalTexture": base,
            "pressedTexture": pressed
        ]

        let iconLabel = SKLabelNode(fontNamed: "SFProRounded-Bold")
        iconLabel.text = icon
        iconLabel.fontSize = 30
        iconLabel.fontColor = .white
        iconLabel.verticalAlignmentMode = .center
        iconLabel.horizontalAlignmentMode = .center
        iconLabel.position = CGPoint(x: -size.width * 0.35, y: 0)
        iconLabel.name = "icon"
        node.addChild(iconLabel)

        let titleLabel = SKLabelNode(fontNamed: "Orbitron-Bold")
        titleLabel.text = title
        titleLabel.fontSize = 18
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: -size.width * 0.15, y: 12)
        titleLabel.name = "title"
        node.addChild(titleLabel)

        let subtitleLabel = SKLabelNode(fontNamed: "SFProRounded-Regular")
        subtitleLabel.text = subtitle
        subtitleLabel.fontSize = 12
        subtitleLabel.fontColor = UIColor.white.withAlphaComponent(0.82)
        subtitleLabel.horizontalAlignmentMode = .left
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.position = CGPoint(x: -size.width * 0.15, y: -16)
        subtitleLabel.name = "subtitle"
        node.addChild(subtitleLabel)

        let border = SKShapeNode(rectOf: CGSize(width: size.width - 6, height: size.height - 6), cornerRadius: 26)
        border.strokeColor = UIColor.white.withAlphaComponent(0.4)
        border.lineWidth = 2
        border.fillColor = .clear
        border.zPosition = -1
        node.addChild(border)

        return node
    }

    public func makeGemIcon(radius: CGFloat) -> SKShapeNode {
        let path = UIBezierPath()
        let width = radius * 1.2
        path.move(to: CGPoint(x: 0, y: radius))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: -width, y: 0))
        path.close()
        let node = SKShapeNode(path: path.cgPath)
        node.fillColor = GamePalette.solarGold
        node.strokeColor = UIColor.white.withAlphaComponent(0.9)
        node.lineWidth = 2
        node.glowWidth = 4
        return node
    }

    public func makeBadgeNode(title: String, subtitle: String, size: CGSize, icon: InterfaceIcon?) -> SKSpriteNode {
        let texture = roundedTexture(size: size,
                                     colors: [GamePalette.royalBlue.withAlphaComponent(0.9), GamePalette.deepNavy.withAlphaComponent(0.9)],
                                     cornerRadius: size.height * 0.45)
        let node = SKSpriteNode(texture: texture)
        node.size = size
        node.name = "badge"

        let border = SKShapeNode(rectOf: size, cornerRadius: size.height * 0.45)
        border.strokeColor = GamePalette.cyan
        border.lineWidth = 2
        border.fillColor = .clear
        border.zPosition = 1
        node.addChild(border)

        var textStartX = -size.width / 2 + size.width * 0.15
        if let icon {
            let diameter = size.height * 0.55
            let iconNode = SKSpriteNode(texture: iconTexture(for: icon, diameter: diameter))
            iconNode.size = CGSize(width: diameter, height: diameter)
            iconNode.position = CGPoint(x: textStartX - size.width * 0.04, y: 0)
            iconNode.name = "icon"
            node.addChild(iconNode)
            textStartX = iconNode.position.x + diameter / 2 + size.width * 0.12
        }

        let titleLabel = SKLabelNode(fontNamed: "Orbitron-Bold")
        titleLabel.text = title
        titleLabel.fontSize = min(20, size.height * 0.32)
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: textStartX, y: size.height * 0.18)
        titleLabel.name = "badgeTitle"
        node.addChild(titleLabel)

        let subtitleLabel = SKLabelNode(fontNamed: "SFProRounded-Regular")
        subtitleLabel.text = subtitle
        subtitleLabel.fontSize = min(14, size.height * 0.24)
        subtitleLabel.fontColor = UIColor.white.withAlphaComponent(0.75)
        subtitleLabel.horizontalAlignmentMode = .left
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.position = CGPoint(x: textStartX, y: -size.height * 0.2)
        subtitleLabel.name = "badgeSubtitle"
        node.addChild(subtitleLabel)

        return node
    }

    public func makeHUDStatNode(title: String, value: String, size: CGSize, icon: InterfaceIcon?, accent: UIColor) -> HUDStatNode {
        let texture = roundedTexture(size: size,
                                     colors: [GamePalette.deepNavy.withAlphaComponent(0.9), GamePalette.royalBlue.withAlphaComponent(0.9)],
                                     cornerRadius: size.height * 0.45)
        let iconNode = icon.map { SKSpriteNode(texture: iconTexture(for: $0, diameter: size.height * 0.6)) }
        return HUDStatNode(size: size,
                           backgroundTexture: texture,
                           title: title,
                           value: value,
                           iconNode: iconNode,
                           accentColor: accent)
    }

    public func makeEventBanner(size: CGSize, icon: InterfaceIcon?) -> EventBannerNode {
        let texture = roundedTexture(size: size,
                                     colors: [GamePalette.neonMagenta.withAlphaComponent(0.9), GamePalette.cyan.withAlphaComponent(0.9)],
                                     cornerRadius: size.height / 2)
        let iconNode = icon.map { SKSpriteNode(texture: iconTexture(for: $0, diameter: size.height * 0.6)) }
        return EventBannerNode(size: size, backgroundTexture: texture, iconNode: iconNode)
    }

    public func makeGhostNode(radius: CGFloat) -> SKNode {
        let container = SKNode()
        container.name = "ghost"

        let outer = SKShapeNode(circleOfRadius: radius)
        outer.fillColor = GamePalette.solarGold.withAlphaComponent(0.16)
        outer.strokeColor = GamePalette.solarGold
        outer.lineWidth = 2
        outer.glowWidth = 6
        outer.alpha = 0.45
        container.addChild(outer)

        let inner = SKShapeNode(circleOfRadius: radius * 0.55)
        inner.fillColor = GamePalette.neonMagenta.withAlphaComponent(0.25)
        inner.strokeColor = GamePalette.cyan
        inner.lineWidth = 1.5
        inner.alpha = 0.6
        container.addChild(inner)

        if let texture = makeParticleTexture(radius: 3, color: GamePalette.solarGold) {
            let trail = SKEmitterNode()
            trail.particleTexture = texture
            trail.particleBirthRate = 36
            trail.particleLifetime = 1.0
            trail.particleAlpha = 0.6
            trail.particleAlphaSpeed = -0.8
            trail.particleSpeed = 18
            trail.particleSpeedRange = 8
            trail.particlePositionRange = CGVector(dx: radius * 0.4, dy: radius * 0.4)
            trail.emissionAngleRange = .pi * 2
            trail.zPosition = -1
            container.addChild(trail)
        }

        return container
    }

    // MARK: Branding

    public func makeLogoNode(size: CGSize) -> SKSpriteNode {
        let image = makeAppIconImage(size: size)
        return SKSpriteNode(texture: SKTexture(image: image))
    }

    public func makeAppIconImage(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return UIImage()
        }

        let rect = CGRect(origin: .zero, size: size)
        drawRoundedGradient(in: context,
                            rect: rect,
                            colors: [GamePalette.deepNavy.cgColor, GamePalette.royalBlue.cgColor, GamePalette.neonMagenta.cgColor],
                            cornerRadius: size.width * 0.24)

        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)

        let orbitRadii: [CGFloat] = [0.64, 0.46, 0.28]
        for (index, ratio) in orbitRadii.enumerated() {
            let radius = min(rect.width, rect.height) * ratio * 0.5
            let color = index % 2 == 0 ? GamePalette.cyan : GamePalette.neonMagenta
            context.setStrokeColor(color.withAlphaComponent(0.9).cgColor)
            context.setLineWidth(max(4, rect.width * 0.04))
            context.addArc(center: .zero, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
            context.strokePath()
        }

        let podRect = CGRect(x: -rect.width * 0.1, y: -rect.width * 0.1, width: rect.width * 0.2, height: rect.width * 0.2)
        context.setFillColor(GamePalette.neonMagenta.cgColor)
        context.fillEllipse(in: podRect)
        context.setStrokeColor(GamePalette.cyan.cgColor)
        context.setLineWidth(max(3, rect.width * 0.03))
        context.strokeEllipse(in: podRect.insetBy(dx: rect.width * 0.01, dy: rect.width * 0.01))

        context.restoreGState()
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }

    public func makeParticleTexture(radius: CGFloat, color: UIColor) -> SKTexture? {
        let size = CGSize(width: radius * 2 + 2, height: radius * 2 + 2)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        let rect = CGRect(origin: .zero, size: size)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image.map(SKTexture.init)
    }

    // MARK: Helpers

    private func gradientTexture(size: CGSize, colors: [UIColor]) -> SKTexture {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let locations = stride(from: 0.0, through: 1.0, by: 1.0 / Double(max(colors.count - 1, 1))).map { CGFloat($0) }
        let cgColors = colors.map { $0.cgColor } as CFArray
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: locations) else {
            return SKTexture()
        }
        let width = Int(size.width)
        let height = Int(size.height)
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width * 4,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return SKTexture()
        }
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: 0, y: size.height),
                                   options: [])
        guard let image = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }

    private func roundedTexture(size: CGSize, colors: [UIColor], cornerRadius: CGFloat) -> SKTexture {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
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

    private func iconTexture(for icon: InterfaceIcon, diameter: CGFloat) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return SKTexture() }

        let draw = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
        GamePalette.deepNavy.withAlphaComponent(0.4).setFill()
        draw.fill()

        context.saveGState()
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(max(2, diameter * 0.08))

        switch icon {
        case .play:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: -diameter * 0.18, y: diameter * 0.24))
            path.addLine(to: CGPoint(x: diameter * 0.28, y: 0))
            path.addLine(to: CGPoint(x: -diameter * 0.18, y: -diameter * 0.24))
            path.close()
            GamePalette.cyan.setFill()
            path.fill()
        case .share:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: -diameter * 0.2, y: -diameter * 0.1))
            path.addLine(to: CGPoint(x: diameter * 0.2, y: diameter * 0.18))
            path.move(to: CGPoint(x: -diameter * 0.2, y: diameter * 0.2))
            path.addLine(to: CGPoint(x: diameter * 0.2, y: -diameter * 0.12))
            GamePalette.cyan.setStroke()
            path.stroke()
            let circle = UIBezierPath(ovalIn: CGRect(x: -diameter * 0.35, y: -diameter * 0.08, width: diameter * 0.2, height: diameter * 0.2))
            GamePalette.neonMagenta.setFill()
            circle.fill()
        case .retry:
            let path = UIBezierPath()
            path.addArc(withCenter: .zero, radius: diameter * 0.32, startAngle: .pi * 0.2, endAngle: .pi * 1.6, clockwise: true)
            GamePalette.cyan.setStroke()
            path.stroke()
            let arrow = UIBezierPath()
            arrow.move(to: CGPoint(x: diameter * 0.32, y: 0))
            arrow.addLine(to: CGPoint(x: diameter * 0.18, y: diameter * 0.12))
            arrow.addLine(to: CGPoint(x: diameter * 0.18, y: -diameter * 0.12))
            arrow.close()
            GamePalette.neonMagenta.setFill()
            arrow.fill()
        case .info:
            let dotDiameter = max(diameter * 0.1, 2.0)
            let dotRect = CGRect(x: -dotDiameter / 2, y: diameter * 0.18, width: dotDiameter, height: dotDiameter)
            let dot = UIBezierPath(ovalIn: dotRect)
            GamePalette.cyan.setFill()
            dot.fill()

            let stem = UIBezierPath()
            stem.move(to: CGPoint(x: 0, y: -diameter * 0.25))
            stem.addLine(to: CGPoint(x: 0, y: diameter * 0.05))
            GamePalette.cyan.setStroke()
            stem.lineWidth = max(2.0, diameter * 0.08)
            stem.stroke()

            let base = UIBezierPath()
            base.move(to: CGPoint(x: -diameter * 0.12, y: -diameter * 0.25))
            base.addLine(to: CGPoint(x: diameter * 0.12, y: -diameter * 0.25))
            GamePalette.cyan.setStroke()
            base.lineWidth = max(2.0, diameter * 0.08)
            base.stroke()
        case .home:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: -diameter * 0.3, y: -diameter * 0.1))
            path.addLine(to: CGPoint(x: 0, y: diameter * 0.3))
            path.addLine(to: CGPoint(x: diameter * 0.3, y: -diameter * 0.1))
            path.close()
            GamePalette.cyan.setStroke()
            path.lineWidth = max(2, diameter * 0.08)
            path.stroke()
            GamePalette.neonMagenta.setFill()
            path.fill()
        case .continue:
            let rect = UIBezierPath(roundedRect: CGRect(x: -diameter * 0.32, y: -diameter * 0.18, width: diameter * 0.64, height: diameter * 0.36), cornerRadius: diameter * 0.18)
            GamePalette.cyan.setStroke()
            rect.stroke()
            let chevron = UIBezierPath()
            chevron.move(to: CGPoint(x: -diameter * 0.12, y: -diameter * 0.12))
            chevron.addLine(to: CGPoint(x: diameter * 0.12, y: 0))
            chevron.addLine(to: CGPoint(x: -diameter * 0.12, y: diameter * 0.12))
            GamePalette.neonMagenta.setStroke()
            chevron.lineWidth = max(2, diameter * 0.08)
            chevron.stroke()
        case .streak:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: -diameter * 0.3, y: -diameter * 0.2))
            path.addLine(to: CGPoint(x: 0, y: diameter * 0.34))
            path.addLine(to: CGPoint(x: diameter * 0.3, y: -diameter * 0.2))
            path.close()
            GamePalette.neonMagenta.setFill()
            path.fill()
        case .trophy:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: -diameter * 0.32, y: diameter * 0.15))
            path.addLine(to: CGPoint(x: diameter * 0.32, y: diameter * 0.15))
            path.addLine(to: CGPoint(x: diameter * 0.18, y: -diameter * 0.1))
            path.addLine(to: CGPoint(x: diameter * 0.1, y: -diameter * 0.26))
            path.addLine(to: CGPoint(x: -diameter * 0.1, y: -diameter * 0.26))
            path.addLine(to: CGPoint(x: -diameter * 0.18, y: -diameter * 0.1))
            path.close()
            GamePalette.solarGold.setFill()
            path.fill()
            GamePalette.cyan.setStroke()
            path.stroke()
        case .level:
            let barWidth = diameter * 0.18
            for i in 0..<3 {
                let height = diameter * (0.2 + CGFloat(i) * 0.2)
                let rect = CGRect(x: CGFloat(i - 1) * barWidth, y: -height / 2, width: barWidth * 0.8, height: height)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: barWidth * 0.3)
                (i == 2 ? GamePalette.cyan : GamePalette.neonMagenta).setFill()
                path.fill()
            }
        case .power:
            let bolt = UIBezierPath()
            bolt.move(to: CGPoint(x: -diameter * 0.12, y: diameter * 0.26))
            bolt.addLine(to: CGPoint(x: diameter * 0.08, y: diameter * 0.08))
            bolt.addLine(to: CGPoint(x: -diameter * 0.02, y: -diameter * 0.06))
            bolt.addLine(to: CGPoint(x: diameter * 0.14, y: -diameter * 0.28))
            bolt.addLine(to: CGPoint(x: -diameter * 0.06, y: -diameter * 0.08))
            bolt.addLine(to: CGPoint(x: diameter * 0.02, y: diameter * 0.06))
            bolt.close()
            GamePalette.solarGold.setFill()
            bolt.fill()
        case .alert:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: diameter * 0.34))
            path.addLine(to: CGPoint(x: diameter * 0.32, y: -diameter * 0.32))
            path.addLine(to: CGPoint(x: -diameter * 0.32, y: -diameter * 0.32))
            path.close()
            GamePalette.solarGold.setFill()
            path.fill()
            let exclamation = UIBezierPath(rect: CGRect(x: -diameter * 0.05, y: -diameter * 0.1, width: diameter * 0.1, height: diameter * 0.24))
            GamePalette.deepNavy.setFill()
            exclamation.fill()
            let dot = UIBezierPath(ovalIn: CGRect(x: -diameter * 0.05, y: -diameter * 0.24, width: diameter * 0.1, height: diameter * 0.1))
            dot.fill()
        case .gems:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: diameter * 0.34))
            path.addLine(to: CGPoint(x: diameter * 0.28, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -diameter * 0.34))
            path.addLine(to: CGPoint(x: -diameter * 0.28, y: 0))
            path.close()
            GamePalette.solarGold.setFill()
            path.fill()
            GamePalette.cyan.setStroke()
            path.lineWidth = max(2, diameter * 0.08)
            path.stroke()
        case .timer:
            let circle = UIBezierPath(ovalIn: CGRect(x: -diameter * 0.3, y: -diameter * 0.3, width: diameter * 0.6, height: diameter * 0.6))
            GamePalette.cyan.setStroke()
            circle.lineWidth = max(2, diameter * 0.08)
            circle.stroke()
            let hand = UIBezierPath()
            hand.move(to: .zero)
            hand.addLine(to: CGPoint(x: 0, y: diameter * 0.2))
            GamePalette.neonMagenta.setStroke()
            hand.lineWidth = max(2, diameter * 0.08)
            hand.stroke()
        }

        context.restoreGState()
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return SKTexture(image: image)
    }

    private func drawRoundedGradient(in context: CGContext, rect: CGRect, colors: [CGColor], cornerRadius: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)
        context.drawLinearGradient(gradient!, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
        context.restoreGState()
    }
}

// MARK: - HUD Support Types

public final class HUDStatNode: SKNode {
    public let contentSize: CGSize
    private let background: SKSpriteNode
    private let highlightNode: SKShapeNode
    private let border: SKShapeNode
    private let valueLabel: SKLabelNode
    private var accentColor: UIColor
    private var highlighted = false

    init(size: CGSize,
         backgroundTexture: SKTexture?,
         title: String,
         value: String,
         iconNode: SKSpriteNode?,
         accentColor: UIColor) {
        self.contentSize = size
        self.accentColor = accentColor
        if let texture = backgroundTexture {
            background = SKSpriteNode(texture: texture)
        } else {
            background = SKSpriteNode(color: GamePalette.deepNavy.withAlphaComponent(0.9), size: size)
        }
        background.size = size
        background.alpha = 0.95

        highlightNode = SKShapeNode(rectOf: size, cornerRadius: size.height * 0.45)
        highlightNode.fillColor = accentColor.withAlphaComponent(0.25)
        highlightNode.strokeColor = .clear
        highlightNode.alpha = 0

        border = SKShapeNode(rectOf: size, cornerRadius: size.height * 0.45)
        border.lineWidth = 2
        border.strokeColor = accentColor
        border.fillColor = .clear

        let padding = size.width * 0.12
        var textX = -size.width / 2 + padding

        super.init()

        addChild(background)
        addChild(highlightNode)
        addChild(border)

        if let iconNode {
            iconNode.size = CGSize(width: iconNode.size.width, height: iconNode.size.height)
            iconNode.position = CGPoint(x: textX + iconNode.size.width / 2, y: 0)
            iconNode.alpha = 0.95
            addChild(iconNode)
            textX = iconNode.position.x + iconNode.size.width / 2 + padding * 0.5
        }

        let titleLabel = SKLabelNode(fontNamed: "SFProRounded-Regular")
        titleLabel.fontSize = min(14, size.height * 0.26)
        titleLabel.fontColor = UIColor.white.withAlphaComponent(0.7)
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: textX, y: size.height * 0.2)
        titleLabel.text = title.uppercased()
        addChild(titleLabel)

        let valueLabel = SKLabelNode(fontNamed: "Orbitron-Bold")
        valueLabel.fontSize = min(26, size.height * 0.5)
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .left
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: textX, y: -size.height * 0.2)
        valueLabel.text = value
        valueLabel.name = "value"
        addChild(valueLabel)
        self.valueLabel = valueLabel
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func updateValue(_ value: String) {
        valueLabel.text = value
    }

    public func setHighlighted(_ highlighted: Bool) {
        guard highlighted != self.highlighted else { return }
        self.highlighted = highlighted
        highlightNode.removeAllActions()
        let targetAlpha: CGFloat = highlighted ? 1.0 : 0.0
        highlightNode.run(SKAction.fadeAlpha(to: targetAlpha, duration: 0.25))
        valueLabel.fontColor = highlighted ? accentColor : .white
        if highlighted {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.03, duration: 0.35),
                SKAction.scale(to: 1.0, duration: 0.35)
            ])
            run(SKAction.repeatForever(pulse), withKey: "hudPulse")
        } else {
            removeAction(forKey: "hudPulse")
            run(SKAction.scale(to: 1.0, duration: 0.2))
        }
    }
}

public final class EventBannerNode: SKNode {
    private let background: SKSpriteNode
    private let border: SKShapeNode
    private let label: SKLabelNode
    private let iconNode: SKSpriteNode?

    init(size: CGSize, backgroundTexture: SKTexture?, iconNode: SKSpriteNode?) {
        if let texture = backgroundTexture {
            background = SKSpriteNode(texture: texture)
        } else {
            background = SKSpriteNode(color: GamePalette.deepNavy.withAlphaComponent(0.9), size: size)
        }
        background.size = size
        background.alpha = 0.95

        border = SKShapeNode(rectOf: size, cornerRadius: size.height / 2)
        border.lineWidth = 2
        border.strokeColor = GamePalette.solarGold
        border.fillColor = .clear

        label = SKLabelNode(fontNamed: "Orbitron-Bold")
        label.fontSize = min(22, size.height * 0.45)
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = iconNode == nil ? .center : .left
        label.position = iconNode == nil ? .zero : CGPoint(x: -size.width * 0.25, y: 0)
        label.name = "label"

        self.iconNode = iconNode
        super.init()

        addChild(background)
        addChild(border)
        if let iconNode {
            iconNode.position = CGPoint(x: -size.width * 0.35, y: 0)
            iconNode.alpha = 0.95
            addChild(iconNode)
        }
        addChild(label)

        alpha = 0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func present(message: String, accent: UIColor) {
        label.text = message
        border.strokeColor = accent
        iconNode?.colorBlendFactor = 0
        removeAllActions()
        run(SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.2),
            SKAction.wait(forDuration: 2.0),
            SKAction.fadeOut(withDuration: 0.3)
        ]))
    }
}

public extension SKSpriteNode {
    func setPressed(_ pressed: Bool) {
        guard let original = userData?["originalTexture"] as? SKTexture,
              let pressedTexture = userData?["pressedTexture"] as? SKTexture else { return }
        texture = pressed ? pressedTexture : original
    }
}

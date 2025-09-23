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
}

public protocol AssetGenerating {
    func makeBackground(size: CGSize) -> SKSpriteNode
    func makePlayerNode() -> SKShapeNode
    func makeRingNode(radius: CGFloat, lineWidth: CGFloat, color: UIColor, glow: CGFloat) -> SKShapeNode
    func makeObstacleNode(size: CGSize) -> SKShapeNode
    func makePowerUpNode(of type: PowerUpType) -> SKShapeNode
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

import Foundation
import UIKit
import CoreGraphics

public struct GameConstants {
    public static let baseSpeed: CGFloat = 100.0
    public static let speedMultiplier: CGFloat = 1.02
    public static let minimumSpawnRate: TimeInterval = 0.6
    public static let baseSpawnRate: TimeInterval = 1.5
    public static let spawnRateReductionPerLevel: TimeInterval = 0.05
    public static let doubleFlipHoldThreshold: TimeInterval = 0.35
    public static let doubleFlipReleaseWindow: TimeInterval = 0.2
    public static let tapCooldown: TimeInterval = 0.15
    public static let nearMissDistance: CGFloat = 12.0
    public static let nearMissMultiplierGain: CGFloat = 0.2
    public static let multiplierDecayFactor: CGFloat = 0.5
    public static let scorePerAction: CGFloat = 10.0
    public static let powerupShieldDuration: TimeInterval = 3.0
    public static let powerupSlowFactor: CGFloat = 0.5
    public static let magnetStrength: CGFloat = 50.0
    public static let tutorialGhostObstacles: Int = 3
    public static let maxRings: Int = 3
    public static let ringRadii: [CGFloat] = [90.0, 140.0, 190.0]
    public static let ringStrokeWidth: CGFloat = 6.0
    public static let frameCaptureInterval: TimeInterval = 0.1
    public static let replayDuration: TimeInterval = 3.0
    public static let particleBirthRate: CGFloat = 100.0
    public static let particleLifetime: CGFloat = 0.5
    public static let milestoneScores: [Int] = [10, 25, 50, 100]
    public static let milestoneStep: Int = 100
    public static let inversionDuration: TimeInterval = 5.0
    public static let meteorShowerDuration: TimeInterval = 6.0
    public static let gravityReversalDuration: TimeInterval = 8.0
    public static let magnetSafeZoneRadius: CGFloat = 24.0
    public static let reviveGemCost: Int = 150
    public static let shieldPowerupGemCost: Int = 120
    public static let starterPackGemGrant: Int = 200
    public static let starterPackSkinIdentifier: String = "nova_pod"
    public static let shieldPowerupDuration: TimeInterval = powerupShieldDuration
}

public enum GamePalette {
    public static let deepNavy = UIColor(hex: "0F172A")
    public static let royalBlue = UIColor(hex: "1E3A8A")
    public static let neonMagenta = UIColor(hex: "F472B6")
    public static let cyan = UIColor(hex: "22D3EE")
    public static let solarGold = UIColor(hex: "FBBF24")
}

public extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if sanitized.count == 3 {
            let chars = Array(sanitized)
            sanitized = "" + String(chars[0]) + String(chars[0]) + String(chars[1]) + String(chars[1]) + String(chars[2]) + String(chars[2])
        }
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

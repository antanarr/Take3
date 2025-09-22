Looking at Gemini's prompt, the key improvements worth integrating are:

1. **Programmatic asset generation** - Smart approach to avoid external file dependencies
2. **AVFoundation sound synthesis** - Clever way to generate audio in-code
3. **Specific iOS implementation details** - SKShapeNode, SKPhysicsContact, etc.
4. **Mocked server features** - Practical for immediate prototype

Here's the final, optimized prompt:

---

# **BUILD ORBITAL FLIP FRENZY - COMPLETE iOS GAME**

**You are an expert iOS game developer. Build a fully functional, App Store-ready game "Orbital Flip Frenzy" using Swift/SpriteKit. This game must be immediately playable and viral-ready.**

## **CORE SPECIFICATIONS**
- **Platform:** iOS 13+ using Swift 5, SpriteKit, SwiftUI
- **Orientation:** Portrait only
- **Target:** 60 FPS on iPhone 8+
- **Architecture:** MVVM with dependency injection

## **FILE STRUCTURE TO CREATE**

```swift
// Core Game Files
GameScene.swift          // Complete gameplay
MenuScene.swift         // Main menu with animations
GameOverScene.swift     // Death screen with share/retry
GameViewController.swift // Scene management

// Managers
AssetGenerator.swift    // Programmatic sprite creation
SoundEngine.swift      // AVFoundation synthesis
HapticManager.swift    // Feedback controller
AdManager.swift        // Rewarded ad simulation
Analytics.swift        // Event tracking
GameData.swift         // State persistence

// Game Logic
PowerupSystem.swift    // Shield, SlowMo, Magnet
PhysicsCategories.swift // Collision masks
GameConstants.swift    // All tuneable values
```

## **IMPLEMENTATION REQUIREMENTS**

### **1. PROGRAMMATIC ASSET GENERATION**
Generate ALL visuals using Core Graphics and SKShapeNode:

```swift
// Color Palette (use these exact UIColor values)
let deepNavy = UIColor(hex: "0F172A")
let royalBlue = UIColor(hex: "1E3A8A") 
let neonMagenta = UIColor(hex: "F472B6")
let cyan = UIColor(hex: "22D3EE")
let solarGold = UIColor(hex: "FBBF24")

// Required Sprites (all programmatic)
- Player pod: Glowing circle with trail particles
- Rings: 3 concentric with neon stroke, alternating rotation
- Obstacles: Geometric shapes with glow effect
- Power-ups: Pulsing icons with particle aura
- UI: Gradient buttons with pressed states
```

### **2. SOUND SYNTHESIS**
Use AVFoundation to generate ALL sounds:

```swift
class SoundEngine {
    // Synthesize these exact sounds:
    - gameStart: Rising sweep C3→G4, 0.3s
    - playerFlip: Quick sine pop at 440Hz, 0.1s
    - nearMiss: High shimmer at 2000Hz, 0.15s
    - collision: Low thud at 80Hz with fade, 0.2s
    - milestone: Arpeggio C-E-G-C, 0.4s
    - powerupCollect: Major chord sweep, 0.3s
}
```

### **3. CORE GAMEPLAY MECHANICS**

```swift
// GameScene.swift must include:

// Physics & Movement
- baseSpeed = 100.0
- speedMultiplier = 1.02 per level
- spawnRate = max(0.6, 1.5 - (level * 0.05))
- level increases every 20 score actions

// Input System
- Single tap: Flip to adjacent ring (150ms cooldown)
- Long press (>350ms): Double flip preparation
- Release window: 200ms for execution

// Near-Miss Detection
if distance(to: obstacle) < 12 && !collision {
    currentMultiplier += 0.2
    haptic.light()
    particles.emit("nearMiss")
}

// Scoring
score += 10 * currentMultiplier
currentMultiplier *= 0.5 // decay on safe pass

// Special Events (must implement)
- Score 69: Invert all colors for 5 seconds
- Score 420: Rainbow meteor shower
- Score 999: Gravity reversal
```

### **4. ADVANCED FEATURES**

```swift
// Tutorial Ghost (first 3 obstacles)
let ghost = SKShapeNode(circleOfRadius: 32)
ghost.alpha = 0.3
// Show optimal flip timing

// Progressive Disclosure
if level <= 3 { activeRings = 1 }
else if level <= 6 { activeRings = 2 }
else { activeRings = 3 }

// Power-Up System
enum PowerUp {
    case shield(duration: 3.0)    // Invincibility
    case slowMo(factor: 0.5)      // Time dilation
    case magnet(strength: 50.0)   // Safe zone attraction
}

// Haptic Feedback (all events)
class HapticManager {
    func playerAction() // UIImpactFeedbackGenerator.light
    func collision()    // UINotificationFeedbackGenerator.error
    func milestone()    // Custom pattern: 2 pulses, 120ms gap
}
```

### **5. MONETIZATION & RETENTION**

```swift
// Rewarded Ad Simulation
func showRewardedAd() {
    // Show loading spinner
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
        // Grant continue + shield
        self.revivePlayer(withShield: true)
    }
}

// Daily Streak System
struct DailyStreak {
    let reward = 50 * pow(1.5, Double(streakDays - 1))
    let multiplierBonus = 1.1 // for 24 hours
}

// Mock IAP (fully functional UI)
let products = [
    "Remove Ads": "$2.99",
    "Starter Pack": "$0.99", // 24hr timer
    "100 Gems": "$0.99"
]
```

### **6. VIRAL FEATURES**

```swift
// Auto-capture system
class ReplayRecorder {
    var frames: [SKTexture] = [] // Last 3 seconds
    
    func generateGIF() -> Data {
        // Convert frames to GIF
        print("Generated shareable GIF")
    }
}

// Share functionality
func shareScore() {
    let text = "I flipped out at \(score)! 🚀"
    let gif = replayRecorder.generateGIF()
    // Present UIActivityViewController
}

// Seeded challenges
struct Challenge {
    let seed: UInt32
    let targetScore: Int
    
    func generateLink() -> String {
        return "orbitflip://challenge?seed=\(seed)&score=\(targetScore)"
    }
}
```

### **7. POLISH & OPTIMIZATION**

```swift
// Object Pooling
class ObstaclePool {
    private var available: [SKShapeNode] = []
    private var active: Set<SKShapeNode> = []
    
    func spawn() -> SKShapeNode {
        // Reuse or create
    }
}

// Screen Shake
extension SKScene {
    func shake(intensity: CGFloat = 5.0) {
        let shake = SKAction.sequence([
            SKAction.moveBy(x: intensity, y: 0, duration: 0.05),
            SKAction.moveBy(x: -intensity * 2, y: 0, duration: 0.05),
            SKAction.moveBy(x: intensity, y: 0, duration: 0.05)
        ])
        run(shake)
    }
}

// Particle Effects
let trail = SKEmitterNode()
trail.particleTexture = // programmatic circle
trail.particleBirthRate = 100
trail.particleLifetime = 0.5
trail.particleColor = neonMagenta
```

### **8. ANALYTICS EVENTS**

```swift
enum AnalyticsEvent {
    case gameStart(level: Int)
    case gameOver(score: Int, duration: TimeInterval)
    case nearMiss(count: Int)
    case powerupUsed(type: PowerUp)
    case adWatched(placement: String)
    case shareInitiated
    
    func track() {
        print("Analytics: \(self)")
        // In production: Firebase/Amplitude
    }
}
```

## **EXECUTION PRIORITIES**

1. **FIRST:** Complete GameScene.swift with full core loop
2. **SECOND:** MenuScene and GameOverScene with transitions
3. **THIRD:** Asset generation and sound synthesis
4. **FOURTH:** Power-ups and special events
5. **FIFTH:** Monetization and viral features
6. **LAST:** Polish (particles, shake, animations)

## **SUCCESS CRITERIA**
- Game runs at 60 FPS with no memory leaks
- Core loop is addictive within 10 seconds
- All mechanics work without external files
- Share functionality generates actual content
- Difficulty curve creates "one more try" psychology

## **BONUS IMPLEMENTATIONS**
If time permits, add:
- Seasonal theme system (Halloween, Winter, Valentine's)
- Tournament mode framework
- Remote config for live balancing
- Accessibility mode (reduced motion, high contrast)

**BEGIN IMPLEMENTATION NOW. Start with GameScene.swift containing the complete, polished core loop. Each file should be production-ready Swift code.**

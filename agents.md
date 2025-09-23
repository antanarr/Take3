# AI Agents for Orbital Flip Frenzy

## Overview
This document contains AI agent prompts for building and maintaining the Orbital Flip Frenzy iOS game. These prompts are designed to work with advanced AI coding assistants to generate production-ready code.

## Primary Agent: Full Game Builder

### Purpose
Generates the complete iOS game from scratch with all core systems, programmatic assets, and sound synthesis.

### Prompt
```
You are an expert iOS game developer. Build a fully functional, App Store-ready game "Orbital Flip Frenzy" using Swift/SpriteKit. This game must be immediately playable and viral-ready. Platform: iOS 13+ using Swift 5, SpriteKit, SwiftUI. Orientation: Portrait only. Target: 60 FPS on iPhone 8+. Architecture: MVVM with dependency injection. Create these files: GameScene.swift for complete gameplay, MenuScene.swift for main menu with animations, GameOverScene.swift for death screen with share/retry, GameViewController.swift for scene management, AssetGenerator.swift for programmatic sprite creation, SoundEngine.swift for AVFoundation synthesis, HapticManager.swift for feedback controller, AdManager.swift for rewarded ad simulation, Analytics.swift for event tracking, GameData.swift for state persistence, PowerupSystem.swift for Shield SlowMo Magnet, PhysicsCategories.swift for collision masks, GameConstants.swift for all tuneable values. Generate ALL visuals using Core Graphics and SKShapeNode. Color Palette: deepNavy UIColor(hex: "0F172A"), royalBlue UIColor(hex: "1E3A8A"), neonMagenta UIColor(hex: "F472B6"), cyan UIColor(hex: "22D3EE"), solarGold UIColor(hex: "FBBF24"). Required Sprites all programmatic: Player pod as glowing circle with trail particles, Rings as 3 concentric with neon stroke alternating rotation, Obstacles as geometric shapes with glow effect, Power-ups as pulsing icons with particle aura, UI as gradient buttons with pressed states. Use AVFoundation to generate ALL sounds. SoundEngine class must synthesize: gameStart as rising sweep C3 to G4 0.3s, playerFlip as quick sine pop at 440Hz 0.1s, nearMiss as high shimmer at 2000Hz 0.15s, collision as low thud at 80Hz with fade 0.2s, milestone as arpeggio C-E-G-C 0.4s, powerupCollect as major chord sweep 0.3s.
GameScene.swift must include physics and movement with baseSpeed = 100.0, speedMultiplier = 1.02 per level, spawnRate = max(0.6, 1.5 - (level * 0.05)), level increases every 20 score actions. Input System: Single tap flips to adjacent ring with 150ms cooldown, Long press over 350ms for double flip preparation, Release window 200ms for execution. Near-Miss Detection: if distance to obstacle < 12 and no collision then currentMultiplier += 0.2, trigger haptic.light(), emit nearMiss particles. Scoring: score += 10 * currentMultiplier, currentMultiplier *= 0.5 on safe pass. Special Events must implement: Score 69 inverts all colors for 5 seconds, Score 420 triggers rainbow meteor shower, Score 999 reverses gravity. Tutorial Ghost for first 3 obstacles: Create SKShapeNode circleOfRadius 32 with alpha 0.3 showing optimal flip timing. Progressive Disclosure: if level <= 3 activeRings = 1, else if level <= 6 activeRings = 2, else activeRings = 3. Power-Up System enum PowerUp with shield duration 3.0 for invincibility, slowMo factor 0.5 for time dilation, magnet strength 50.0 for safe zone attraction. HapticManager class: playerAction uses UIImpactFeedbackGenerator.light, collision uses UINotificationFeedbackGenerator.error, milestone uses custom pattern 2 pulses 120ms gap. Rewarded Ad Simulation: func showRewardedAd() shows loading spinner, DispatchQueue.main.asyncAfter deadline .now() + 5.0 grants revivePlayer withShield true. Daily Streak System: struct DailyStreak with reward = 50 * pow(1.5, Double(streakDays - 1)) and multiplierBonus = 1.1 for 24 hours. Mock IAP fully functional UI: products array with Remove Ads $2.99, Starter Pack $0.99 with 24hr timer, 100 Gems $0.99. ReplayRecorder class: var frames array of SKTexture for last 3 seconds, func generateGIF() returns Data converting frames to GIF, print Generated shareable GIF. Share functionality: func shareScore() creates text "I flipped out at score!" with replay GIF, presents UIActivityViewController. Seeded challenges: struct Challenge with seed UInt32 and targetScore Int, func generateLink() returns orbitflip://challenge?seed=seed&score=targetScore. ObstaclePool class for object pooling: private var available array of SKShapeNode, private var active Set of SKShapeNode, func spawn() returns SKShapeNode reusing or creating. Screen Shake extension SKScene: func shake intensity CGFloat = 5.0 using SKAction sequence moveBy x intensity y 0 duration 0.05 three times. Particle Effects: let trail = SKEmitterNode() with particleTexture programmatic circle, particleBirthRate 100, particleLifetime 0.5, particleColor neonMagenta. Analytics Events enum: gameStart with level, gameOver with score and duration, nearMiss with count, powerupUsed with type, adWatched with placement, shareInitiated, func track() prints Analytics self, note in production use Firebase or Amplitude. Execution Priorities: FIRST complete GameScene.swift with full core loop, SECOND MenuScene and GameOverScene with transitions, THIRD asset generation and sound synthesis, FOURTH power-ups and special events, FIFTH monetization and viral features, LAST polish with particles shake animations. Success Criteria: Game runs at 60 FPS with no memory leaks, Core loop is addictive within 10 seconds, All mechanics work without external files, Share functionality generates actual content, Difficulty curve creates one more try psychology. Bonus Implementations if time permits: Seasonal theme system for Halloween Winter Valentine's, Tournament mode framework, Remote config for live balancing, Accessibility mode with reduced motion and high contrast. Begin implementation now. Start with GameScene.swift containing the complete polished core loop. Each file should be production-ready Swift code.
```

### Expected Output
- 13 Swift files with complete implementation
- No external asset dependencies
- Fully functional game loop
- Programmatic graphics and sound

## Secondary Agents

### Agent: Bug Fixer
```
You are an iOS game developer debugging Orbital Flip Frenzy. The game uses SpriteKit, programmatic assets, and synthesized sounds. Analyze the provided error or bug description and fix it while maintaining the game's viral mechanics and 60 FPS performance. Preserve the neon synthwave aesthetic and ensure all fixes work with existing systems.
```

### Agent: Feature Adder
```
You are enhancing Orbital Flip Frenzy with new features. The game uses programmatic SKShapeNodes with colors: deepNavy #0F172A, royalBlue #1E3A8A, neonMagenta #F472B6, cyan #22D3EE, solarGold #FBBF24. Implement the requested feature maintaining 60 FPS, using no external assets, and ensuring viral potential. All visuals must be programmatic, all sounds synthesized.
```

### Agent: Performance Optimizer
```
You are optimizing Orbital Flip Frenzy for maximum performance. Current target: 60 FPS on iPhone 8+. Analyze the code for memory leaks, inefficient sprite usage, or excessive allocations. Implement object pooling, texture atlasing, and lazy loading while maintaining all game features. Focus on smooth gameplay during intense moments.
```

### Agent: Monetization Tuner
```
You are optimizing Orbital Flip Frenzy's monetization. Current setup: Rewarded ads for continues, IAPs for cosmetics and ad removal. Analyze and improve ARPDAU targeting $0.15+ by Day 30. Adjust ad frequency, IAP pricing, and reward mechanics. Maintain non-intrusive monetization that doesn't harm retention.
```

### Agent: App Store Optimizer
```
You are preparing Orbital Flip Frenzy for App Store submission. Generate: App Store description (4000 chars), subtitle (30 chars), keywords (100 chars), what's new text, promotional text (170 chars). Create screenshot descriptions for 6.5" and 5.5" devices. Ensure all text emphasizes viral hooks and one-touch gameplay.
```

## Usage Instructions

### For New Development
1. Use the Primary Agent prompt with a fresh AI session
2. Request files one at a time for best results
3. Start with GameScene.swift as specified
4. Test each file before requesting the next

### For Modifications
1. Provide the relevant agent with existing code
2. Clearly specify the desired change
3. Request diff-style output for easy integration

### For Debugging
1. Use Bug Fixer agent with error messages
2. Include relevant code context
3. Specify device and iOS version if relevant

## File Structure
```
OrbitFlipFrenzy/
├── Game/
│   ├── GameScene.swift
│   ├── MenuScene.swift
│   ├── GameOverScene.swift
│   └── GameViewController.swift
├── Managers/
│   ├── AssetGenerator.swift
│   ├── SoundEngine.swift
│   ├── HapticManager.swift
│   ├── AdManager.swift
│   └── Analytics.swift
├── Systems/
│   ├── PowerupSystem.swift
│   ├── PhysicsCategories.swift
│   └── GameConstants.swift
└── Data/
    └── GameData.swift
```

## Key Metrics
- **Performance**: 60 FPS minimum
- **Size**: < 100MB total
- **Retention**: D1: 40%, D7: 20%, D30: 10%
- **Monetization**: $0.15+ ARPDAU by Day 30
- **Virality**: 10% share rate

## Color Reference
```
swift
let deepNavy = UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1.0)
let royalBlue = UIColor(red: 0.12, green: 0.23, blue: 0.54, alpha: 1.0)
let neonMagenta = UIColor(red: 0.96, green: 0.45, blue: 0.71, alpha: 1.0)
let cyan = UIColor(red: 0.13, green: 0.83, blue: 0.93, alpha: 1.0)
let solarGold = UIColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1.0)
```

## Sound Specifications
| Sound | Frequency | Duration | Type |
|-------|-----------|----------|------|
| gameStart | C3→G4 | 0.3s | Sweep |
| playerFlip | 440Hz | 0.1s | Sine pop |
| nearMiss | 2000Hz | 0.15s | Shimmer |
| collision | 80Hz | 0.2s | Thud + fade |
| milestone | C-E-G-C | 0.4s | Arpeggio |
| powerupCollect | Major chord | 0.3s | Sweep |

## Notes
- All assets are programmatically generated
- No external image or sound files required
- Designed for viral TikTok/social sharing
- Optimized for one-finger gameplay
- Built-in replay recording system

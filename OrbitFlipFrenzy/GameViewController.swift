import Foundation
import SpriteKit
import SwiftUI
import UIKit

final class GameViewController: UIViewController {
    private lazy var skView: SKView = {
        let view = SKView(frame: UIScreen.main.bounds)
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        return view
    }()

    private let container = DependencyContainer()
    private var currentGameScene: GameScene?

    override func loadView() {
        view = skView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GamePalette.deepNavy
        presentMenu()
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    private func presentMenu() {
        let scene = container.makeMenuScene(size: view.bounds.size)
        scene.menuDelegate = self
        skView.presentScene(scene, transition: .crossFade(withDuration: 0.5))
    }

    private func presentGame() {
        let scene = container.makeGameScene(size: view.bounds.size)
        scene.gameDelegate = self
        currentGameScene = scene
        skView.presentScene(scene, transition: .doorsOpenVertical(withDuration: 0.6))
    }

    private func presentGameOver(with result: GameResult) {
        guard let gameScene = currentGameScene else { return }
        gameScene.isPaused = true
        let scene = container.makeGameOverScene(size: view.bounds.size, result: result)
        scene.overDelegate = self
        skView.presentScene(scene, transition: .crossFade(withDuration: 0.5))
        currentGameScene = gameScene
    }
}

extension GameViewController: MenuSceneDelegate {
    func menuSceneDidStartGame(_ scene: MenuScene) {
        presentGame()
    }

    func menuScene(_ scene: MenuScene, didSelectProduct name: String) {
        container.presentPurchasePrompt(for: name, from: self)
    }
}

extension GameViewController: GameSceneDelegate {
    func gameSceneDidEnd(_ scene: GameScene, result: GameResult) {
        currentGameScene = scene
        presentGameOver(with: result)
    }
}

extension GameViewController: GameOverSceneDelegate {
    func gameOverSceneDidRequestRetry(_ scene: GameOverScene) {
        presentGame()
    }

    func gameOverSceneDidRequestRevive(_ scene: GameOverScene) {
        guard let gameScene = currentGameScene else { return }
        gameScene.isPaused = false
        skView.presentScene(gameScene, transition: .doorsOpenVertical(withDuration: 0.5))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            gameScene.revivePlayer(withShield: true)
        }
    }

    func gameOverSceneDidFinishShare(_ scene: GameOverScene) {
        // No-op: analytics already handled in scene
    }

    func gameOverSceneDidReturnHome(_ scene: GameOverScene) {
        presentMenu()
    }
}

private final class DependencyContainer {
    let assets = AssetGenerator()
    let sound = SoundEngine()
    let haptics = HapticManager()
    let analytics = Analytics()
    let adManager = AdManager()
    let data = GameData.shared

    func makeMenuScene(size: CGSize) -> MenuScene {
        let viewModel = MenuScene.ViewModel(assets: assets, data: data, sound: sound)
        let scene = MenuScene(size: size, viewModel: viewModel, assets: assets)
        return scene
    }

    func makeGameScene(size: CGSize) -> GameScene {
        let powerups = PowerupManager()
        let viewModel = GameScene.ViewModel(analytics: analytics,
                                            data: data,
                                            sound: sound,
                                            haptics: haptics)
        let scene = GameScene(size: size,
                              viewModel: viewModel,
                              assets: assets,
                              sound: sound,
                              haptics: haptics,
                              powerups: powerups,
                              adManager: adManager)
        return scene
    }

    func makeGameOverScene(size: CGSize, result: GameResult) -> GameOverScene {
        let viewModel = GameOverScene.ViewModel(assets: assets,
                                                adManager: adManager,
                                                sound: sound,
                                                haptics: haptics,
                                                analytics: analytics)
        let scene = GameOverScene(size: size, viewModel: viewModel, assets: assets, result: result)
        return scene
    }

    func presentPurchasePrompt(for product: String, from controller: UIViewController) {
        let message: String
        switch product {
        case "Starter Pack":
            message = "Starter Pack unlocks Nova Pod skin + 200 gems for just $0.99!"
        case "Remove Ads":
            message = "Remove all ads and keep rewarded options for $2.99."
        case "100 Gems":
            message = "Grab 100 gems instantly for $0.99."
        case "550 Gems":
            message = "550 gems + bonus to customize your pod."
        case "1200 Gems":
            message = "1200 gems + massive bonus trails."
        default:
            message = product
        }
        let alert = UIAlertController(title: product, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        controller.present(alert, animated: true)
    }
}

struct GameView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> GameViewController {
        GameViewController()
    }

    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}

@main
struct OrbitFlipFrenzyApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .edgesIgnoringSafeArea(.all)
        }
    }
}

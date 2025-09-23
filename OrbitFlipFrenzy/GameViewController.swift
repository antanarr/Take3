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

    func menuSceneDidRequestRestore(_ scene: MenuScene) {
        container.restorePurchases(from: self)
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
    let assets: AssetGenerator
    let sound: SoundEngine
    let haptics: HapticManager
    let analytics: Analytics
    let adManager: AdManager
    let data: GameData
    let purchases: PurchaseManager
    let remoteConfig: RemoteConfigManager

    init() {
        self.assets = AssetGenerator()
        self.sound = SoundEngine()
        self.haptics = HapticManager()
        self.remoteConfig = RemoteConfigManager()
        self.analytics = Analytics(remoteConfig: remoteConfig)
        self.data = GameData.shared
        self.data.configure(remoteConfig: remoteConfig)
        self.adManager = AdManager()
        self.purchases = PurchaseManager(data: data, analytics: analytics, remoteConfig: remoteConfig)
        self.adManager.preload()
        self.remoteConfig.refresh()
    }

    func makeMenuScene(size: CGSize) -> MenuScene {
        let viewModel = MenuScene.ViewModel(assets: assets,
                                            data: data,
                                            sound: sound,
                                            purchases: purchases,
                                            analytics: analytics,
                                            remoteConfig: remoteConfig)
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
                                                analytics: analytics,
                                                data: data)
        let scene = GameOverScene(size: size, viewModel: viewModel, assets: assets, result: result)
        return scene
    }

    func presentPurchasePrompt(for product: String, from controller: UIViewController) {
        guard let id = PurchaseManager.ProductID(displayName: product) else {
            let alert = UIAlertController(title: product,
                                          message: "Product not available in StoreKit catalog.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            controller.present(alert, animated: true)
            return
        }
        purchases.presentStorefront(for: id, from: controller)
    }

    func restorePurchases(from controller: UIViewController) {
        purchases.presentRestorePurchases(from: controller)
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

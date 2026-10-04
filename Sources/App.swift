import UIKit
import SpriteKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Art.build()
        Sound.shared.start()
        if CommandLine.arguments.contains("-dumpart") { dumpArt() }
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        c.delegateClass = SceneDelegate.self
        return c
    }

    // Debug helper: writes every generated sprite to the temp folder (used to build the icon artwork).
    func dumpArt() {
        let dir = NSTemporaryDirectory() + "art/"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for (k, img) in Art.images { try? img.pngData()?.write(to: URL(fileURLWithPath: dir + k + ".png")) }
        print("ART DUMPED TO", dir)
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        w.rootViewController = GameViewController()
        w.makeKeyAndVisible()
        window = w
    }
}

final class GameViewController: UIViewController {
    var skView: SKView { view as! SKView }

    override func loadView() { view = SKView(frame: UIScreen.main.bounds) }

    override func viewDidLoad() {
        super.viewDidLoad()
        let v = skView
        v.preferredFramesPerSecond = 60          // locked 60 fps
        v.ignoresSiblingOrder = true             // lets SpriteKit batch draw calls by texture
        v.shouldCullNonVisibleNodes = true
        v.allowsTransparency = false
        v.contentScaleFactor = UIScreen.main.nativeScale   // 2x on a 4K Apple TV output
        v.showsFPS = false
        if CommandLine.arguments.contains("-fps") { Input.shared.showFPS = true }
        if CommandLine.arguments.contains("-autoplay") {
            v.presentScene(GameScene(autoplay: true))
        } else {
            v.presentScene(MenuScene(size: CGSize(width: W, height: H)))
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for p in presses where p.type == .menu {
            if let s = skView.scene as? MenuButtonHandling, s.handleMenuButton() { return }
        }
        super.pressesBegan(presses, with: event)
    }

    override var preferredUserInterfaceStyle: UIUserInterfaceStyle { .dark }
}

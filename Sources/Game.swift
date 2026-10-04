import SpriteKit
import GameController

let W: CGFloat = 1920
let H: CGFloat = 1080

protocol MenuButtonHandling: AnyObject { func handleMenuButton() -> Bool }

func clampf(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { max(lo, min(hi, v)) }

// MARK: - pooled entities (no allocation during play)

class PooledSprite: SKSpriteNode {
    var live = false
    init(key: String) {
        let size = Art.images[key]?.size ?? CGSize(width: 16, height: 16)
        super.init(texture: Art.t(key), color: .clear, size: size)
        isHidden = true
    }
    required init?(coder aDecoder: NSCoder) { fatalError() }
    func setKey(_ key: String) {
        texture = Art.t(key)
        size = Art.images[key]?.size ?? size
    }
}

final class Bullet: PooledSprite {
    var vx: CGFloat = 0, vy: CGFloat = 0
    var damage = 1
    var radius: CGFloat = 8
    var homing = false
}

final class Particle: PooledSprite {
    var vx: CGFloat = 0, vy: CGFloat = 0
    var life: CGFloat = 0, maxLife: CGFloat = 1
    var startScale: CGFloat = 1
}

final class Pickup: PooledSprite {
    var kind = 0
    var t: CGFloat = 0
}

final class Enemy: PooledSprite {
    enum Kind { case bee, wasp, beetle, moth, dragonfly, mantis, queen }
    var kind = Kind.bee
    var hp = 1, maxHp = 1
    var enterT: CGFloat = 0
    var slot = CGPoint.zero
    var start = CGPoint.zero
    var origin = CGPoint.zero
    var mode = 0                 // grid: 0 entering, 1 holding, 2 diving
    var pattern = 0              // 0 grid, 1 swoop, 2 ring, 3 zigzag, 4 boss
    var phase: CGFloat = 0
    var amp: CGFloat = 0
    var freq: CGFloat = 0
    var dir: CGFloat = 1
    var moveSpeed: CGFloat = 0
    var angle: CGFloat = 0
    var fireTimer: CGFloat = 1
    var radius: CGFloat = 30
    var scoreValue = 100
    var flash: CGFloat = 0
    var bossT: CGFloat = 0
    var attackStep = 0
    var spawnedAdds = false
}

// MARK: - shared background

final class Backdrop {
    let sky: SKSpriteNode
    var leaves: [SKSpriteNode] = []
    var dust: [SKSpriteNode] = []
    init(parent: SKNode) {
        sky = SKSpriteNode(texture: Art.t("sky"), size: CGSize(width: W, height: H))
        sky.anchorPoint = .zero; sky.zPosition = -30
        parent.addChild(sky)
        for i in 0..<2 {
            let d = SKSpriteNode(texture: Art.t("dust"), size: CGSize(width: W, height: H))
            d.anchorPoint = .zero; d.position = CGPoint(x: 0, y: CGFloat(i) * H); d.zPosition = -20; d.blendMode = .add; d.alpha = 0.8
            parent.addChild(d); dust.append(d)
            let l = SKSpriteNode(texture: Art.t("leaves"), size: CGSize(width: W, height: H))
            l.anchorPoint = .zero; l.position = CGPoint(x: 0, y: CGFloat(i) * H); l.zPosition = -10
            parent.addChild(l); leaves.append(l)
        }
    }
    func update(_ dt: CGFloat, speed: CGFloat = 1) {
        for t in dust { t.position.y -= 150 * dt * speed; if t.position.y <= -H { t.position.y += 2 * H } }
        for t in leaves { t.position.y -= 70 * dt * speed; if t.position.y <= -H { t.position.y += 2 * H } }
    }
}

func label(_ text: String, size: CGFloat, color: UIColor = .white, bold: Bool = true) -> SKLabelNode {
    let l = SKLabelNode(fontNamed: bold ? "AvenirNext-Heavy" : "AvenirNext-DemiBold")
    l.text = text; l.fontSize = size; l.fontColor = color
    l.verticalAlignmentMode = .center
    return l
}

// MARK: - menu

final class MenuScene: SKScene, MenuButtonHandling {
    enum Screen { case title, controls }
    var screen = Screen.title
    var items: [SKLabelNode] = []
    var selected = 0
    var waiting: Action?
    var backdrop: Backdrop!
    let ui = SKNode()
    var footer = SKLabelNode()
    var last: TimeInterval = 0
    var bugs: [(SKSpriteNode, CGFloat, CGFloat)] = []
    var t: CGFloat = 0

    override init(size: CGSize) {
        super.init(size: CGSize(width: W, height: H))
        scaleMode = .aspectFill
        anchorPoint = .zero
    }
    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        backdrop = Backdrop(parent: self)
        addChild(ui)
        for i in 0..<7 {
            let keys = ["bee", "wasp", "beetle", "moth", "dragonfly"]
            let s = SKSpriteNode(texture: Art.t(keys[i % keys.count]), size: Art.images[keys[i % keys.count]]!.size)
            s.setScale(0.9); s.zPosition = 1
            addChild(s)
            bugs.append((s, CGFloat(i) * 0.9, 160 + CGFloat(i % 3) * 70))
        }
        buildTitle()
    }

    func clearUI() { ui.removeAllChildren(); items.removeAll() }

    func buildTitle() {
        screen = .title; clearUI(); selected = 0
        let glow = label("HIVE STRIKE", size: 190, color: rgb(255, 190, 40, 0.5))
        glow.position = CGPoint(x: W / 2, y: 800); glow.setScale(1.02); glow.zPosition = 2
        let title = label("HIVE STRIKE", size: 190, color: rgb(255, 214, 70))
        title.position = CGPoint(x: W / 2, y: 800); title.zPosition = 3
        ui.addChild(glow); ui.addChild(title)
        let sub = label("DEFEND THE GARDEN  -  STOP THE SWARM", size: 38, color: rgb(170, 255, 230), bold: false)
        sub.position = CGPoint(x: W / 2, y: 690); ui.addChild(sub)
        let hi = label("HIGH SCORE  " + String(format: "%07d", UserDefaults.standard.integer(forKey: "hiscore")), size: 40, color: .white, bold: false)
        hi.position = CGPoint(x: W / 2, y: 140); ui.addChild(hi)
        addItems(["PLAY", "CONTROLS"], startY: 520)
        footer = label("Move: stick / D-pad  -  Select: A button or Siri Remote click", size: 32, color: rgb(200, 220, 230, 0.8), bold: false)
        footer.position = CGPoint(x: W / 2, y: 70); ui.addChild(footer)
        refresh()
    }

    func controlRows() -> [String] {
        let inp = Input.shared
        return ["FIRE BUTTON:  " + (inp.bindings[.fire] ?? .a).label,
                "BOMB BUTTON:  " + (inp.bindings[.bomb] ?? .b).label,
                "AUTO-FIRE:  " + (inp.autoFire ? "ON" : "OFF"),
                "SHOW FPS / RESOLUTION:  " + (inp.showFPS ? "ON" : "OFF"),
                "RESET DEFAULTS",
                "BACK"]
    }

    func buildControls() {
        screen = .controls; clearUI(); selected = 0
        let title = label("CONTROLS", size: 120, color: rgb(255, 214, 70))
        title.position = CGPoint(x: W / 2, y: 900); ui.addChild(title)
        let pad = label("Controller:  " + Input.shared.controllerName, size: 40, color: rgb(170, 255, 230), bold: false)
        pad.position = CGPoint(x: W / 2, y: 810); ui.addChild(pad)
        addItems(controlRows(), startY: 700, spacing: 92)
        footer = label("Select a row, then press the new gamepad button.  Menu button = back.", size: 32, color: rgb(200, 220, 230, 0.8), bold: false)
        footer.position = CGPoint(x: W / 2, y: 130); ui.addChild(footer)
        let help = label("Siri Remote: swipe = move, click = fire, Play/Pause = bomb", size: 30, color: rgb(200, 220, 230, 0.6), bold: false)
        help.position = CGPoint(x: W / 2, y: 80); ui.addChild(help)
        refresh()
    }

    func addItems(_ names: [String], startY: CGFloat, spacing: CGFloat = 110) {
        for (i, n) in names.enumerated() {
            let l = label(n, size: 64)
            l.position = CGPoint(x: W / 2, y: startY - CGFloat(i) * spacing); l.zPosition = 3
            ui.addChild(l); items.append(l)
        }
    }

    func refresh() {
        if screen == .controls {
            let rows = controlRows()
            for (i, l) in items.enumerated() { l.text = rows[i] }
            if let w = waiting { items[w == .fire ? 0 : 1].text = (w == .fire ? "FIRE BUTTON:  " : "BOMB BUTTON:  ") + "PRESS A BUTTON..." }
        }
        for (i, l) in items.enumerated() {
            let on = i == selected
            l.fontColor = on ? rgb(255, 214, 70) : rgb(255, 255, 255, 0.72)
            l.setScale(on ? 1.1 : 1.0)
        }
    }

    func handleMenuButton() -> Bool {
        if waiting != nil { waiting = nil; refresh(); return true }
        if screen == .controls { buildTitle(); Sound.shared.play("select", 0.6); return true }
        return false
    }

    func activate() {
        Sound.shared.play("select", 0.7)
        if screen == .title {
            if selected == 0 { view?.presentScene(GameScene(autoplay: false), transition: .fade(withDuration: 0.5)) } else { buildControls() }
            return
        }
        switch selected {
        case 0: waiting = .fire
        case 1: waiting = .bomb
        case 2: Input.shared.autoFire.toggle()
        case 3: Input.shared.showFPS.toggle()
        case 4: Input.shared.resetDefaults()
        default: buildTitle(); return
        }
        refresh()
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(min(0.05, last == 0 ? 0.016 : currentTime - last)); last = currentTime
        t += dt
        Input.shared.poll()
        backdrop.update(dt, speed: 0.8)
        for (i, b) in bugs.enumerated() {
            let a = t * 0.6 + b.1
            b.0.position = CGPoint(x: W / 2 + cos(a * (1 + CGFloat(i % 2) * 0.3)) * (700 + CGFloat(i) * 20), y: 430 + sin(a * 1.3) * b.2)
            b.0.zRotation = sin(a * 1.3) * 0.25
        }
        if let w = waiting {
            if let p = Input.shared.newPad { Input.shared.bind(w, to: p); waiting = nil; Sound.shared.play("select", 0.8); refresh() }
            return
        }
        let inp = Input.shared
        if inp.navY != 0, !items.isEmpty {
            selected = (selected - inp.navY + items.count) % items.count
            Sound.shared.play("move", 0.6); refresh()
        }
        if inp.confirmPressed { activate() }
        if inp.backPressed, screen == .controls { buildTitle() }
    }
}

// MARK: - the game

final class GameScene: SKScene, MenuButtonHandling {
    enum State { case playing, paused, gameOver }
    var state = State.playing
    var autoplay = false
    let world = SKNode()
    var backdrop: Backdrop!
    var player: SKSpriteNode!
    var shieldNode: SKSpriteNode!
    var flashNode: SKSpriteNode!

    var pBullets: [Bullet] = [], eBullets: [Bullet] = [], enemies: [Enemy] = []
    var parts: [Particle] = [], pickups: [Pickup] = []
    var pbIdx = 0, ebIdx = 0, partIdx = 0

    var score = 0, lives = 3, bombs = 3, wave = 0, weaponLevel = 1
    var hasShield = false
    var invuln: CGFloat = 0, fireCD: CGFloat = 0, respawn: CGFloat = 0
    var playerAlive = true
    var volley = 0
    var gameTime: CGFloat = 0
    var last: TimeInterval = 0
    var diveTimer: CGFloat = 2
    var ringActive = false, ringCX: CGFloat = W / 2, ringCY: CGFloat = H + 350, ringTarget: CGFloat = 700
    var waveClearDelay: CGFloat = 0
    var shake: CGFloat = 0

    var scoreLabel = SKLabelNode(), waveLabel = SKLabelNode(), hiLabel = SKLabelNode(), fpsLabel = SKLabelNode()
    var lifeIcons: [SKSpriteNode] = [], bombIcons: [SKSpriteNode] = []
    var bossBack: SKSpriteNode!, bossFront: SKSpriteNode!
    var bossRef: Enemy?
    var overlay: [SKLabelNode] = []
    var pauseSel = 0
    var frames = 0, fpsClock: CGFloat = 0
    var hudDirty = true

    override init(size: CGSize) {
        super.init(size: CGSize(width: W, height: H))
        scaleMode = .aspectFill
        anchorPoint = .zero
    }
    convenience init(autoplay: Bool) { self.init(size: CGSize(width: W, height: H)); self.autoplay = autoplay }
    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: setup

    override func didMove(to view: SKView) {
        backdrop = Backdrop(parent: self)
        addChild(world)
        player = SKSpriteNode(texture: Art.t("player"), size: Art.images["player"]!.size)
        player.position = CGPoint(x: W / 2, y: 170); player.zPosition = 50
        world.addChild(player)
        shieldNode = SKSpriteNode(texture: Art.t("shield"), size: CGSize(width: 190, height: 190))
        shieldNode.zPosition = 51; shieldNode.isHidden = true; shieldNode.blendMode = .add
        world.addChild(shieldNode)
        for _ in 0..<110 { let b = Bullet(key: "pbullet"); b.zPosition = 40; b.blendMode = .add; world.addChild(b); pBullets.append(b) }
        for _ in 0..<260 { let b = Bullet(key: "ebullet"); b.zPosition = 45; world.addChild(b); eBullets.append(b) }
        for _ in 0..<64 { let e = Enemy(key: "bee"); e.zPosition = 30; world.addChild(e); enemies.append(e) }
        for _ in 0..<420 { let p = Particle(key: "glow"); p.zPosition = 60; p.blendMode = .add; world.addChild(p); parts.append(p) }
        for _ in 0..<10 { let p = Pickup(key: "pu0"); p.zPosition = 35; world.addChild(p); pickups.append(p) }
        flashNode = SKSpriteNode(color: .white, size: CGSize(width: W, height: H))
        flashNode.anchorPoint = .zero; flashNode.zPosition = 200; flashNode.alpha = 0; addChild(flashNode)
        buildHUD()
        Sound.shared.setMusic(true)
        nextWave()
    }

    func buildHUD() {
        scoreLabel = label("", size: 54, color: .white); scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 70, y: H - 70)
        waveLabel = label("", size: 46, color: rgb(255, 214, 70)); waveLabel.position = CGPoint(x: W / 2, y: H - 70)
        hiLabel = label("", size: 40, color: rgb(170, 255, 230), bold: false); hiLabel.horizontalAlignmentMode = .right
        hiLabel.position = CGPoint(x: W - 70, y: H - 70)
        fpsLabel = label("", size: 28, color: rgb(255, 255, 255, 0.7), bold: false); fpsLabel.position = CGPoint(x: W / 2, y: 30)
        for l in [scoreLabel, waveLabel, hiLabel, fpsLabel] { l.zPosition = 100; addChild(l) }
        for i in 0..<6 {
            let s = SKSpriteNode(texture: Art.t("life"), size: Art.images["life"]!.size)
            s.position = CGPoint(x: 70 + CGFloat(i) * 54, y: 60); s.zPosition = 100; addChild(s); lifeIcons.append(s)
            let b = SKSpriteNode(texture: Art.t("bomb"), size: Art.images["bomb"]!.size)
            b.position = CGPoint(x: W - 70 - CGFloat(i) * 54, y: 60); b.zPosition = 100; addChild(b); bombIcons.append(b)
        }
        bossBack = SKSpriteNode(color: rgb(0, 0, 0, 0.55), size: CGSize(width: 900, height: 18))
        bossBack.position = CGPoint(x: W / 2, y: H - 125); bossBack.zPosition = 100; bossBack.isHidden = true; addChild(bossBack)
        bossFront = SKSpriteNode(color: rgb(255, 80, 70), size: CGSize(width: 900, height: 18))
        bossFront.anchorPoint = CGPoint(x: 0, y: 0.5)
        bossFront.position = CGPoint(x: W / 2 - 450, y: H - 125); bossFront.zPosition = 101; bossFront.isHidden = true; addChild(bossFront)
    }

    func refreshHUD() {
        hudDirty = false
        let hi = max(score, UserDefaults.standard.integer(forKey: "hiscore"))
        scoreLabel.text = "SCORE  " + String(format: "%07d", score)
        waveLabel.text = "WAVE " + String(wave)
        hiLabel.text = "HIGH  " + String(format: "%07d", hi)
        for (i, s) in lifeIcons.enumerated() { s.isHidden = i >= lives - (playerAlive ? 1 : 0) }
        for (i, b) in bombIcons.enumerated() { b.isHidden = i >= bombs }
    }

    // MARK: pools

    func grab(_ arr: [Bullet], _ idx: inout Int) -> Bullet? {
        for _ in 0..<arr.count {
            idx = (idx + 1) % arr.count
            if !arr[idx].live { return arr[idx] }
        }
        return nil
    }

    func grabEnemy() -> Enemy? { enemies.first(where: { !$0.live }) }

    func fireEnemyBullet(_ x: CGFloat, _ y: CGFloat, _ vx: CGFloat, _ vy: CGFloat, sting: Bool = false) {
        guard let b = grab(eBullets, &ebIdx) else { return }
        b.setKey(sting ? "sting" : "ebullet")
        b.live = true; b.isHidden = false; b.homing = false
        b.position = CGPoint(x: x, y: y); b.vx = vx; b.vy = vy; b.radius = sting ? 9 : 12
        b.zRotation = sting ? atan2(vy, vx) + .pi / 2 + .pi : 0
        b.setScale(1)
    }

    func burst(_ p: CGPoint, count: Int, color: UIColor, speed: CGFloat, size: CGFloat = 1, life: CGFloat = 0.7) {
        for _ in 0..<count {
            partIdx = (partIdx + 1) % parts.count
            let q = parts[partIdx]
            let a = CGFloat.random(in: 0..<(2 * .pi)), v = CGFloat.random(in: 0.2...1) * speed
            q.live = true; q.isHidden = false
            q.position = p; q.vx = cos(a) * v; q.vy = sin(a) * v
            q.maxLife = life * CGFloat.random(in: 0.6...1.2); q.life = q.maxLife
            q.startScale = size * CGFloat.random(in: 0.5...1.2)
            q.color = color; q.colorBlendFactor = 1
            q.setScale(q.startScale); q.alpha = 1
        }
    }

    // MARK: waves

    func nextWave() {
        wave += 1
        hudDirty = true
        let banner = label(wave % 5 == 0 ? "WAVE \(wave)  -  BOSS" : "WAVE \(wave)", size: 120, color: rgb(255, 214, 70))
        banner.position = CGPoint(x: W / 2, y: H / 2 + 120); banner.zPosition = 150; banner.alpha = 0
        addChild(banner)
        banner.run(.sequence([.fadeIn(withDuration: 0.25), .wait(forDuration: 1.2), .fadeOut(withDuration: 0.5), .removeFromParent()]))
        Sound.shared.play(wave % 5 == 0 ? "boss" : "wave", 0.9)
        if wave % 5 == 0 { spawnBoss() } else {
            switch (wave - 1) % 4 {
            case 0: spawnGrid()
            case 1: spawnSwoop()
            case 2: spawnRing()
            default: spawnZigzag()
            }
        }
    }

    func setup(_ e: Enemy, _ kind: Enemy.Kind, hp: Int, radius: CGFloat, score: Int, tex: String) {
        e.live = true; e.isHidden = true; e.kind = kind
        e.setKey(tex)
        e.hp = hp; e.maxHp = hp; e.radius = radius; e.scoreValue = score
        e.enterT = 0; e.flash = 0; e.mode = 0; e.setScale(1); e.zRotation = 0; e.colorBlendFactor = 0
        e.fireTimer = CGFloat.random(in: 1.2...3.4); e.spawnedAdds = false; e.bossT = 0; e.attackStep = 0
    }

    func spawnGrid() {
        let cols = min(10, 7 + wave / 4), rows = min(5, 2 + wave / 3)
        for r in 0..<rows {
            for c in 0..<cols {
                guard let e = grabEnemy() else { return }
                let strong = r == 0 && wave > 3
                setup(e, strong ? .wasp : .bee, hp: strong ? 3 : 1 + wave / 6, radius: strong ? 38 : 34, score: strong ? 250 : 100, tex: strong ? "wasp" : "bee")
                e.pattern = 0
                e.slot = CGPoint(x: W / 2 + (CGFloat(c) - CGFloat(cols - 1) / 2) * 148, y: 900 - CGFloat(r) * 108)
                e.start = CGPoint(x: (r + c) % 2 == 0 ? -120 : W + 120, y: H + 120)
                e.enterT = -CGFloat(r * cols + c) * 0.09
                e.position = e.start
            }
        }
        diveTimer = 3
    }

    func spawnSwoop() {
        let n = min(18, 9 + wave)
        let fromLeft = Bool.random()
        for i in 0..<n {
            guard let e = grabEnemy() else { return }
            setup(e, .moth, hp: 2 + wave / 6, radius: 40, score: 150, tex: "moth")
            e.pattern = 1
            e.dir = fromLeft ? 1 : -1
            e.origin = CGPoint(x: fromLeft ? -140 : W + 140, y: 760 + CGFloat(i % 2) * 40)
            e.amp = 230; e.freq = 2.0; e.phase = 0
            e.moveSpeed = 330 + CGFloat(wave) * 7
            e.enterT = -CGFloat(i) * 0.38
            e.position = e.origin
        }
    }

    func spawnRing() {
        let n = min(14, 8 + wave / 2)
        ringActive = true; ringCX = W / 2; ringCY = H + 350; ringTarget = 690
        for i in 0..<n {
            guard let e = grabEnemy() else { return }
            setup(e, .beetle, hp: 4 + wave / 4, radius: 44, score: 200, tex: "beetle")
            e.pattern = 2
            e.angle = CGFloat(i) / CGFloat(n) * 2 * .pi
            e.position = CGPoint(x: ringCX, y: ringCY)
            e.isHidden = false
        }
    }

    func spawnZigzag() {
        let n = min(12, 6 + wave / 2)
        for i in 0..<n {
            guard let e = grabEnemy() else { return }
            setup(e, .dragonfly, hp: 2 + wave / 6, radius: 38, score: 180, tex: "dragonfly")
            e.pattern = 3
            e.origin = CGPoint(x: 260 + CGFloat(i % 4) * 460, y: H + 120)
            e.amp = 190; e.phase = CGFloat(i) * 0.9; e.moveSpeed = 250 + CGFloat(wave) * 6
            e.enterT = -CGFloat(i) * 0.55
            e.position = e.origin
        }
    }

    func spawnBoss() {
        guard let e = grabEnemy() else { return }
        let queen = (wave / 5) % 2 == 0
        let hp = Int(Double(queen ? 520 : 380) * (1 + Double(wave) / 12))
        setup(e, queen ? .queen : .mantis, hp: hp, radius: queen ? 130 : 110, score: queen ? 5000 : 3000, tex: queen ? "queen" : "mantis")
        e.pattern = 4
        e.position = CGPoint(x: W / 2, y: H + 280)
        e.isHidden = false
        e.fireTimer = 3
        bossRef = e
        bossBack.isHidden = false; bossFront.isHidden = false; bossFront.xScale = 1
    }

    // MARK: player actions

    let patterns: [[(CGFloat, CGFloat)]] = [
        [(0, 0)],
        [(-16, 0), (16, 0)],
        [(0, 0), (-28, 6), (28, -6)],
        [(-16, 0), (16, 0), (-36, 10), (36, -10)],
        [(0, 0), (-20, 4), (20, -4), (-40, 12), (40, -12)]
    ]

    func shoot() {
        let pat = patterns[min(4, weaponLevel - 1)]
        for (dx, deg) in pat {
            guard let b = grab(pBullets, &pbIdx) else { break }
            b.setKey("pbullet"); b.live = true; b.isHidden = false; b.homing = false
            let a = deg * .pi / 180
            b.position = CGPoint(x: player.position.x + dx, y: player.position.y + 50)
            b.vx = sin(a) * 1750; b.vy = cos(a) * 1750; b.damage = 1; b.radius = 12
            b.zRotation = -a
        }
        volley += 1
        if weaponLevel >= 5 && volley % 4 == 0, let m = grab(pBullets, &pbIdx) {
            m.setKey("missile"); m.live = true; m.isHidden = false; m.homing = true
            m.position = CGPoint(x: player.position.x, y: player.position.y + 40)
            m.vx = 0; m.vy = 900; m.damage = 4; m.radius = 14
        }
        Sound.shared.play(weaponLevel >= 3 ? "shoot2" : "shoot", 0.5)
    }

    func useBomb() {
        guard bombs > 0, playerAlive else { return }
        bombs -= 1; hudDirty = true
        Sound.shared.play("bomb")
        flashNode.alpha = 0.85; flashNode.run(.fadeOut(withDuration: 0.6))
        shake = 18
        let ring = SKSpriteNode(texture: Art.t("ring"), size: CGSize(width: 220, height: 220))
        ring.position = player.position; ring.zPosition = 70; ring.blendMode = .add; ring.color = rgb(255, 120, 80); ring.colorBlendFactor = 1
        world.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 12, duration: 0.7), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
        for b in eBullets where b.live { b.live = false; b.isHidden = true; burst(b.position, count: 2, color: rgb(255, 200, 120), speed: 200, size: 0.6, life: 0.4) }
        for e in enemies where e.live && !e.isHidden { damage(e, e.pattern == 4 ? 60 : 30) }
    }

    func playerHit() {
        guard invuln <= 0, playerAlive else { return }
        if hasShield {
            hasShield = false; shieldNode.isHidden = true; invuln = 0.8
            Sound.shared.play("shieldHit"); burst(player.position, count: 24, color: rgb(120, 240, 255), speed: 420, size: 0.9)
            return
        }
        lives -= 1; hudDirty = true
        playerAlive = false
        player.isHidden = true
        weaponLevel = max(1, weaponLevel - 1)
        burst(player.position, count: 70, color: rgb(255, 160, 60), speed: 560, size: 1.3, life: 1)
        burst(player.position, count: 40, color: rgb(120, 245, 215), speed: 420, size: 1, life: 0.9)
        Sound.shared.play("playerHit"); shake = 22
        for b in eBullets where b.live && hypot(b.position.x - player.position.x, b.position.y - player.position.y) < 320 { b.live = false; b.isHidden = true }
        if lives <= 0 { endGame() } else { respawn = 1.4 }
    }

    func endGame() {
        state = .gameOver
        let hi = UserDefaults.standard.integer(forKey: "hiscore")
        if score > hi { UserDefaults.standard.set(score, forKey: "hiscore") }
        Sound.shared.play("gameOver")
        let g = label("GAME OVER", size: 150, color: rgb(255, 90, 80)); g.position = CGPoint(x: W / 2, y: H / 2 + 120)
        let s = label("SCORE  " + String(format: "%07d", score) + (score > hi ? "   NEW HIGH SCORE!" : ""), size: 60, color: .white); s.position = CGPoint(x: W / 2, y: H / 2 - 10)
        let p = label("Press A or Select to continue", size: 44, color: rgb(170, 255, 230), bold: false); p.position = CGPoint(x: W / 2, y: H / 2 - 120)
        overlay = [g, s, p]
        for l in overlay { l.zPosition = 300; addChild(l) }
    }

    func showPause() {
        state = .paused; pauseSel = 0
        let dim = label("PAUSED", size: 130, color: rgb(255, 214, 70)); dim.position = CGPoint(x: W / 2, y: H / 2 + 170)
        let a = label("RESUME", size: 70); a.position = CGPoint(x: W / 2, y: H / 2 + 20)
        let b = label("QUIT TO TITLE", size: 70); b.position = CGPoint(x: W / 2, y: H / 2 - 100)
        overlay = [dim, a, b]
        for l in overlay { l.zPosition = 300; addChild(l) }
        refreshPause()
    }

    func refreshPause() {
        for (i, l) in overlay.enumerated() where i > 0 {
            let on = i - 1 == pauseSel
            l.fontColor = on ? rgb(255, 214, 70) : rgb(255, 255, 255, 0.7); l.setScale(on ? 1.1 : 1)
        }
    }

    func closeOverlay() { overlay.forEach { $0.removeFromParent() }; overlay = [] }

    func handleMenuButton() -> Bool {
        switch state {
        case .playing: showPause(); return true
        case .paused: closeOverlay(); state = .playing; return true
        case .gameOver: view?.presentScene(MenuScene(size: size), transition: .fade(withDuration: 0.5)); return true
        }
    }

    // MARK: damage / pickups

    func damage(_ e: Enemy, _ amount: Int) {
        e.hp -= amount; e.flash = 0.1
        if e.hp > 0 {
            if e.pattern == 4, let boss = bossRef { bossFront.xScale = max(0, CGFloat(boss.hp) / CGFloat(boss.maxHp)) }
            return
        }
        kill(e)
    }

    func kill(_ e: Enemy) {
        e.live = false; e.isHidden = true
        let big = e.pattern == 4
        burst(e.position, count: big ? 160 : 26, color: rgb(255, 170, 60), speed: big ? 760 : 380, size: big ? 2 : 1, life: big ? 1.3 : 0.7)
        burst(e.position, count: big ? 80 : 12, color: rgb(255, 255, 200), speed: big ? 500 : 260, size: big ? 1.4 : 0.8, life: 0.5)
        Sound.shared.play(big ? "bigExplode" : "explode", big ? 1 : 0.55)
        score += e.scoreValue; hudDirty = true
        if big {
            shake = 30; bossRef = nil; bossBack.isHidden = true; bossFront.isHidden = true
            for b in eBullets where b.live { b.live = false; b.isHidden = true }
            for _ in 0..<4 { spawnPickup(at: CGPoint(x: e.position.x + CGFloat.random(in: -140...140), y: e.position.y + CGFloat.random(in: -60...60))) }
        } else if Int.random(in: 0..<100) < 11 { spawnPickup(at: e.position) }
    }

    func spawnPickup(at p: CGPoint) {
        guard let pk = pickups.first(where: { !$0.live }) else { return }
        let r = Int.random(in: 0..<100)
        pk.kind = r < 40 ? 0 : (r < 62 ? 1 : (r < 88 ? 2 : 3))
        pk.setKey("pu\(pk.kind)")
        pk.live = true; pk.isHidden = false; pk.position = p; pk.t = 0
    }

    func collect(_ pk: Pickup) {
        pk.live = false; pk.isHidden = true
        hudDirty = true
        switch pk.kind {
        case 0: if weaponLevel < 5 { weaponLevel += 1; Sound.shared.play("pickup") } else { score += 500; Sound.shared.play("pickup") }
        case 1: hasShield = true; shieldNode.isHidden = false; Sound.shared.play("pickup")
        case 2: bombs = min(6, bombs + 1); Sound.shared.play("pickup")
        default: lives = min(6, lives + 1); Sound.shared.play("life")
        }
        burst(pk.position, count: 16, color: .white, speed: 300, size: 0.8, life: 0.5)
    }

    // MARK: main loop

    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(min(1.0 / 30.0, last == 0 ? 1.0 / 60.0 : currentTime - last)); last = currentTime
        Input.shared.poll()
        updateFPS(dt)
        switch state {
        case .paused:
            if Input.shared.navY != 0 { pauseSel = 1 - pauseSel; Sound.shared.play("move", 0.6); refreshPause() }
            if Input.shared.confirmPressed {
                Sound.shared.play("select", 0.7)
                if pauseSel == 0 { closeOverlay(); state = .playing } else { view?.presentScene(MenuScene(size: size), transition: .fade(withDuration: 0.4)) }
            }
            return
        case .gameOver:
            backdrop.update(dt, speed: 0.4)
            updateParticles(dt)
            if Input.shared.confirmPressed || autoplay { view?.presentScene(autoplay ? GameScene(autoplay: true) : MenuScene(size: size), transition: .fade(withDuration: 0.5)) }
            return
        case .playing: break
        }
        gameTime += dt
        backdrop.update(dt)
        updatePlayer(dt)
        updateEnemies(dt)
        updateBullets(dt)
        updatePickups(dt)
        updateParticles(dt)
        collide()
        if waveActive() == false {
            waveClearDelay += dt
            if waveClearDelay > 1.6 { waveClearDelay = 0; score += 250 * wave; hudDirty = true; nextWave() }
        } else { waveClearDelay = 0 }
        if shake > 0 {
            shake = max(0, shake - 60 * dt)
            world.position = CGPoint(x: CGFloat.random(in: -shake...shake), y: CGFloat.random(in: -shake...shake))
        } else { world.position = .zero }
        if hudDirty { refreshHUD() }
    }

    func waveActive() -> Bool {
        for e in enemies where e.live { return true }
        return false
    }

    func updateFPS(_ dt: CGFloat) {
        frames += 1; fpsClock += dt
        if fpsClock >= 0.5 {
            if Input.shared.showFPS {
                let nb = UIScreen.main.nativeBounds
                fpsLabel.text = "\(Int(nb.width))x\(Int(nb.height))  -  \(Int((CGFloat(frames) / fpsClock).rounded())) fps"
            } else { fpsLabel.text = "" }
            frames = 0; fpsClock = 0
        }
    }

    func aiMove() -> CGVector {
        let px = player.position.x, py = player.position.y
        var best: Enemy?, bestD = CGFloat.infinity
        for e in enemies where e.live && !e.isHidden && e.position.y < H - 40 {
            let d = abs(e.position.x - px) + (H - e.position.y) * 0.15
            if d < bestD { bestD = d; best = e }
        }
        let tx = best?.position.x ?? W / 2
        var dodge: CGFloat = 0
        for b in eBullets where b.live && b.position.y > py - 30 && b.position.y - py < 360 && abs(b.position.x - px) < 120 {
            dodge += (px >= b.position.x ? 1 : -1) * (1 - (b.position.y - py) / 360)
        }
        var dx = clampf((tx - px) / 140, -1, 1)
        if dodge != 0 { dx = clampf(dodge * 2.2, -1, 1) }
        let tooLow = px < 140 || px > W - 140
        if tooLow { dx = px < 140 ? 0.6 : -0.6 }
        let dy = clampf((190 - py) / 120, -1, 1)
        if bombs > 0 && eBullets.filter({ $0.live }).count > 55 { useBomb() }
        return CGVector(dx: dx, dy: dy)
    }

    func updatePlayer(_ dt: CGFloat) {
        let inp = Input.shared
        if !playerAlive {
            respawn -= dt
            if respawn <= 0 && lives > 0 {
                playerAlive = true; player.isHidden = false; invuln = 2.2
                player.position = CGPoint(x: W / 2, y: 170); hudDirty = true
            }
            return
        }
        var mv = inp.move
        if autoplay { mv = aiMove() }
        let speed: CGFloat = 960
        player.position.x = clampf(player.position.x + mv.dx * speed * dt, 70, W - 70)
        player.position.y = clampf(player.position.y + mv.dy * speed * dt, 100, 620)
        player.zRotation += (-mv.dx * 0.22 - player.zRotation) * min(1, dt * 10)
        shieldNode.position = player.position
        if hasShield { shieldNode.zRotation += dt * 1.5 }
        if invuln > 0 { invuln -= dt; player.alpha = Int(invuln * 14) % 2 == 0 ? 0.35 : 1 } else { player.alpha = 1 }
        fireCD -= dt
        if (inp.fireHeld || inp.autoFire || autoplay) && fireCD <= 0 { shoot(); fireCD = weaponLevel >= 4 ? 0.095 : 0.115 }
        if inp.bombPressed { useBomb() }
        if bombs <= 0 && autoplay { bombs = 3; hudDirty = true }
    }

    func enemyFire(_ e: Enemy) {
        let p = e.position
        let tx = player.position.x - p.x, ty = player.position.y - p.y
        let d = max(1, hypot(tx, ty))
        let spd = min(640, 360 + CGFloat(wave) * 12)
        switch e.kind {
        case .bee, .wasp:
            fireEnemyBullet(p.x, p.y - 30, tx / d * spd, ty / d * spd)
            if e.kind == .wasp { fireEnemyBullet(p.x - 24, p.y - 30, tx / d * spd * 0.9 - 80, ty / d * spd * 0.9); fireEnemyBullet(p.x + 24, p.y - 30, tx / d * spd * 0.9 + 80, ty / d * spd * 0.9) }
            Sound.shared.play("enemyShot", 0.3)
        case .moth:
            for k in -1...1 { fireEnemyBullet(p.x, p.y - 30, CGFloat(k) * 150, -spd * 0.9, sting: true) }
            Sound.shared.play("enemyShot", 0.3)
        case .beetle:
            for k in 0..<8 { let a = CGFloat(k) / 8 * 2 * .pi + e.angle; fireEnemyBullet(p.x, p.y, cos(a) * spd * 0.6, sin(a) * spd * 0.6) }
            Sound.shared.play("enemyShot", 0.35)
        case .dragonfly:
            for k in 0..<2 { fireEnemyBullet(p.x + CGFloat(k * 2 - 1) * 20, p.y - 30, tx / d * spd * 1.1, ty / d * spd * 1.1, sting: true) }
            Sound.shared.play("enemyShot", 0.3)
        default: break
        }
    }

    func bossAttack(_ e: Enemy) {
        let p = e.position
        let tx = player.position.x - p.x, ty = player.position.y - p.y
        let d = max(1, hypot(tx, ty))
        let spd: CGFloat = 430 + CGFloat(wave) * 6
        e.attackStep += 1
        switch e.attackStep % 3 {
        case 0:
            let n = 22
            for k in 0..<n { let a = CGFloat(k) / CGFloat(n) * 2 * .pi + CGFloat(e.attackStep) * 0.3; fireEnemyBullet(p.x, p.y - 40, cos(a) * spd * 0.7, sin(a) * spd * 0.7) }
        case 1:
            let base = atan2(ty, tx)
            for k in -3...3 { let a = base + CGFloat(k) * 0.13; fireEnemyBullet(p.x, p.y - 60, cos(a) * spd, sin(a) * spd, sting: true) }
        default:
            for k in -4...4 { fireEnemyBullet(p.x + CGFloat(k) * 70, p.y - 60, tx / d * 60, -spd * 0.85) }
        }
        Sound.shared.play("enemyShot", 0.5)
    }

    func updateEnemies(_ dt: CGFloat) {
        if ringActive {
            if ringCY > ringTarget { ringCY = max(ringTarget, ringCY - 230 * dt) } else { ringCY -= 14 * dt }
            ringCX = W / 2 + sin(gameTime * 0.5) * 120
        }
        var holders: [Enemy] = []
        var ringAlive = false
        for e in enemies where e.live {
            e.enterT += dt
            if e.enterT < 0 { continue }
            if e.isHidden { e.isHidden = false }
            switch e.pattern {
            case 0:
                if e.mode == 0 {
                    let p = clampf(e.enterT / 1.5, 0, 1), k = p * p * (3 - 2 * p)
                    e.position = CGPoint(x: e.start.x + (e.slot.x - e.start.x) * k, y: e.start.y + (e.slot.y - e.start.y) * k - sin(p * .pi) * 160)
                    if p >= 1 { e.mode = 1 }
                } else if e.mode == 1 {
                    e.position = CGPoint(x: e.slot.x + sin(gameTime * 0.9) * 130, y: e.slot.y + sin(gameTime * 1.7 + e.slot.x * 0.01) * 12)
                    holders.append(e)
                } else {
                    e.origin.y -= (430 + CGFloat(wave) * 14) * dt
                    e.position.x += (player.position.x - e.position.x) * min(1, dt * 1.3)
                    e.position.y = e.origin.y
                    e.zRotation = clampf((player.position.x - e.position.x) * -0.0008, -0.5, 0.5)
                    if e.origin.y < -100 { e.mode = 0; e.enterT = 0; e.start = CGPoint(x: e.slot.x, y: H + 120); e.position = e.start; e.zRotation = 0 }
                }
            case 1:
                e.position = CGPoint(x: e.origin.x + e.dir * e.moveSpeed * e.enterT, y: e.origin.y + sin(e.enterT * e.freq + e.phase) * e.amp)
                if e.enterT > 1.5 && (e.position.x < -180 || e.position.x > W + 180) { e.live = false; e.isHidden = true }
            case 2:
                ringAlive = true
                let a = e.angle + gameTime * 0.9
                e.position = CGPoint(x: ringCX + cos(a) * 330, y: ringCY + sin(a) * 190)
            case 3:
                e.position = CGPoint(x: e.origin.x + sin(e.enterT * 2.2 + e.phase) * e.amp, y: e.origin.y - e.enterT * e.moveSpeed)
                if e.position.y < -120 { e.live = false; e.isHidden = true }
            default:
                e.bossT += dt
                if e.bossT < 3 {
                    e.position = CGPoint(x: W / 2, y: H + 280 - (H + 280 - 790) * (e.bossT / 3))
                } else {
                    let sp: CGFloat = e.kind == .queen ? 0.6 : 0.8
                    e.position = CGPoint(x: W / 2 + sin((e.bossT - 3) * sp) * 600, y: 790 + sin(e.bossT * 1.3) * 30)
                    if !e.spawnedAdds && e.hp < e.maxHp / 2 {
                        e.spawnedAdds = true
                        for i in 0..<8 {
                            guard let a = grabEnemy() else { break }
                            setup(a, .moth, hp: 2, radius: 40, score: 150, tex: "moth")
                            a.pattern = 1; a.dir = i % 2 == 0 ? 1 : -1
                            a.origin = CGPoint(x: a.dir > 0 ? -140 : W + 140, y: 560 + CGFloat(i) * 22); a.amp = 120; a.freq = 2.4; a.phase = 0
                            a.moveSpeed = 420; a.enterT = -CGFloat(i) * 0.3; a.position = a.origin
                        }
                    }
                }
            }
            if e.flash > 0 { e.flash -= dt; e.color = .white; e.colorBlendFactor = e.flash > 0 ? 0.75 : 0 } else if e.colorBlendFactor != 0 { e.colorBlendFactor = 0 }
            if e.pattern == 4 && e.bossT < 3 { continue }
            if e.position.y < H - 30 && e.position.y > 40 && (e.pattern != 0 || e.mode != 0) {
                e.fireTimer -= dt
                if e.fireTimer <= 0 {
                    if e.pattern == 4 { bossAttack(e); e.fireTimer = max(0.8, 1.7 - CGFloat(wave) * 0.025) }
                    else { enemyFire(e); e.fireTimer = CGFloat.random(in: 1.6...3.8) / (1 + CGFloat(wave) * 0.07) }
                }
            }
        }
        if ringActive && !ringAlive { ringActive = false }
        diveTimer -= dt
        if diveTimer <= 0, !holders.isEmpty {
            let e = holders[Int.random(in: 0..<holders.count)]
            e.mode = 2; e.origin = e.position
            diveTimer = max(0.8, 2.6 - CGFloat(wave) * 0.1)
        }
    }

    func updateBullets(_ dt: CGFloat) {
        for b in pBullets where b.live {
            if b.homing {
                var tgt: Enemy?, bd = CGFloat.infinity
                for e in enemies where e.live && !e.isHidden {
                    let d = hypot(e.position.x - b.position.x, e.position.y - b.position.y)
                    if d < bd { bd = d; tgt = e }
                }
                if let t = tgt {
                    let ax = t.position.x - b.position.x, ay = t.position.y - b.position.y, d = max(1, hypot(ax, ay))
                    b.vx += (ax / d * 1500 - b.vx) * min(1, dt * 4)
                    b.vy += (ay / d * 1500 - b.vy) * min(1, dt * 4)
                }
                b.zRotation = atan2(b.vy, b.vx) - .pi / 2
            }
            b.position.x += b.vx * dt; b.position.y += b.vy * dt
            if b.position.y > H + 60 || b.position.x < -60 || b.position.x > W + 60 { b.live = false; b.isHidden = true }
        }
        for b in eBullets where b.live {
            b.position.x += b.vx * dt; b.position.y += b.vy * dt
            if b.position.y < -60 || b.position.y > H + 80 || b.position.x < -60 || b.position.x > W + 60 { b.live = false; b.isHidden = true }
        }
    }

    func updatePickups(_ dt: CGFloat) {
        for p in pickups where p.live {
            p.t += dt
            p.position.y -= 170 * dt
            p.position.x += sin(p.t * 3) * 40 * dt
            p.setScale(1 + sin(p.t * 6) * 0.08)
            if p.position.y < -60 { p.live = false; p.isHidden = true }
        }
    }

    func updateParticles(_ dt: CGFloat) {
        for q in parts where q.live {
            q.life -= dt
            if q.life <= 0 { q.live = false; q.isHidden = true; continue }
            q.position.x += q.vx * dt; q.position.y += q.vy * dt
            q.vx *= 1 - 1.8 * dt; q.vy *= 1 - 1.8 * dt
            let k = q.life / q.maxLife
            q.alpha = k; q.setScale(q.startScale * (0.4 + k * 0.8))
        }
    }

    func collide() {
        for b in pBullets where b.live {
            for e in enemies where e.live && !e.isHidden && !(e.pattern == 0 && e.mode == 0 && e.position.y > H - 40) {
                let dx = e.position.x - b.position.x, dy = e.position.y - b.position.y
                let rr = e.radius + b.radius
                if dx * dx + dy * dy < rr * rr {
                    b.live = false; b.isHidden = true
                    burst(b.position, count: b.homing ? 10 : 3, color: rgb(140, 245, 255), speed: 260, size: 0.45, life: 0.3)
                    if !b.homing { Sound.shared.play("hit", 0.18) }
                    damage(e, b.damage)
                    break
                }
            }
        }
        guard playerAlive, invuln <= 0 else {
            for pk in pickups where pk.live { checkPickup(pk) }
            return
        }
        let px = player.position.x, py = player.position.y
        for b in eBullets where b.live {
            let dx = b.position.x - px, dy = b.position.y - py
            let rr = b.radius + 13
            if dx * dx + dy * dy < rr * rr { b.live = false; b.isHidden = true; playerHit(); break }
        }
        if playerAlive && invuln <= 0 {
            for e in enemies where e.live && !e.isHidden {
                let dx = e.position.x - px, dy = e.position.y - py
                let rr = e.radius * 0.75 + 13
                if dx * dx + dy * dy < rr * rr { if e.pattern != 4 { damage(e, 4) }; playerHit(); break }
            }
        }
        for pk in pickups where pk.live { checkPickup(pk) }
    }

    func checkPickup(_ pk: Pickup) {
        guard playerAlive else { return }
        let dx = pk.position.x - player.position.x, dy = pk.position.y - player.position.y
        if dx * dx + dy * dy < 70 * 70 { collect(pk) }
    }
}

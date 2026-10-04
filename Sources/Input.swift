import GameController
import CoreGraphics

// Gamepad buttons that actions can be bound to.
enum Pad: String, CaseIterable {
    case a, b, x, y, l1, r1, l2, r2
    var label: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"
        case .l1: return "L1 / LB"
        case .r1: return "R1 / RB"
        case .l2: return "L2 / LT"
        case .r2: return "R2 / RT"
        }
    }
}

enum Action: String, CaseIterable { case fire, bomb }

// Reads every connected controller (extended gamepads and the Siri Remote) once per frame.
final class Input {
    static let shared = Input()

    // continuous state
    var move = CGVector.zero
    var fireHeld = false
    var bombHeld = false
    // one-frame edges
    var bombPressed = false
    var confirmPressed = false
    var backPressed = false
    var navX = 0
    var navY = 0
    var newPad: Pad?

    var bindings: [Action: Pad] = [.fire: .a, .bomb: .b]
    var autoFire = false { didSet { UserDefaults.standard.set(autoFire, forKey: "autoFire") } }
    var showFPS = false { didSet { UserDefaults.standard.set(showFPS, forKey: "showFPS") } }

    private var prevPads = Set<Pad>()
    private var prevBomb = false, prevConfirm = false, prevBack = false
    private var prevNavX = 0, prevNavY = 0

    init() {
        let d = UserDefaults.standard
        for a in Action.allCases {
            if let s = d.string(forKey: "bind." + a.rawValue), let p = Pad(rawValue: s) { bindings[a] = p }
        }
        autoFire = d.bool(forKey: "autoFire")
        showFPS = d.bool(forKey: "showFPS")
    }

    func bind(_ action: Action, to pad: Pad) {
        // swapping keeps the two actions on different buttons
        if let other = Action.allCases.first(where: { $0 != action && bindings[$0] == pad }) {
            bindings[other] = bindings[action]
            UserDefaults.standard.set(bindings[other]!.rawValue, forKey: "bind." + other.rawValue)
        }
        bindings[action] = pad
        UserDefaults.standard.set(pad.rawValue, forKey: "bind." + action.rawValue)
    }

    func resetDefaults() {
        bindings = [.fire: .a, .bomb: .b]
        for a in Action.allCases { UserDefaults.standard.removeObject(forKey: "bind." + a.rawValue) }
        autoFire = false
    }

    var controllerName: String {
        if let c = GCController.controllers().first(where: { $0.extendedGamepad != nil }) { return c.vendorName ?? "Game controller" }
        if GCController.controllers().first(where: { $0.microGamepad != nil }) != nil { return "Siri Remote" }
        return "No controller"
    }

    private func down(_ g: GCExtendedGamepad, _ p: Pad) -> Bool {
        switch p {
        case .a: return g.buttonA.isPressed
        case .b: return g.buttonB.isPressed
        case .x: return g.buttonX.isPressed
        case .y: return g.buttonY.isPressed
        case .l1: return g.leftShoulder.isPressed
        case .r1: return g.rightShoulder.isPressed
        case .l2: return g.leftTrigger.isPressed
        case .r2: return g.rightTrigger.isPressed
        }
    }

    func poll() {
        var mx: Float = 0, my: Float = 0
        var fire = false, bomb = false, confirm = false, back = false
        var pads = Set<Pad>()
        for c in GCController.controllers() {
            if let g = c.extendedGamepad {
                mx += g.leftThumbstick.xAxis.value + g.dpad.xAxis.value
                my += g.leftThumbstick.yAxis.value + g.dpad.yAxis.value
                for p in Pad.allCases where down(g, p) { pads.insert(p) }
                fire = fire || down(g, bindings[.fire] ?? .a)
                bomb = bomb || down(g, bindings[.bomb] ?? .b)
                confirm = confirm || g.buttonA.isPressed
                back = back || g.buttonB.isPressed
            } else if let m = c.microGamepad {
                m.reportsAbsoluteDpadValues = false
                m.allowsRotation = true
                mx += m.dpad.xAxis.value
                my += m.dpad.yAxis.value
                fire = fire || m.buttonA.isPressed
                bomb = bomb || m.buttonX.isPressed
                confirm = confirm || m.buttonA.isPressed
            }
        }
        let clamp: (Float) -> CGFloat = { CGFloat(max(-1, min(1, $0))) }
        move = CGVector(dx: clamp(mx), dy: clamp(my))
        fireHeld = fire
        bombHeld = bomb
        bombPressed = bomb && !prevBomb
        confirmPressed = confirm && !prevConfirm
        backPressed = back && !prevBack
        prevBomb = bomb; prevConfirm = confirm; prevBack = back
        let nx = move.dx > 0.6 ? 1 : (move.dx < -0.6 ? -1 : 0)
        let ny = move.dy > 0.6 ? 1 : (move.dy < -0.6 ? -1 : 0)
        navX = nx != prevNavX ? nx : 0
        navY = ny != prevNavY ? ny : 0
        prevNavX = nx; prevNavY = ny
        newPad = pads.subtracting(prevPads).first
        prevPads = pads
    }
}

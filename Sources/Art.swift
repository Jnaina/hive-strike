import UIKit
import SpriteKit

// All artwork is drawn procedurally with Core Graphics (original designs) and packed into one
// runtime texture atlas, so every in-game sprite batches into a single draw call.
// Sprites are rendered at 2x so they stay crisp when the Apple TV outputs 4K.

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> UIColor {
    UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
}

enum Art {
    private static var atlas: SKTextureAtlas?
    private static var tex: [String: SKTexture] = [:]
    static var images: [String: UIImage] = [:]

    static func t(_ k: String) -> SKTexture { tex[k] ?? SKTexture() }

    static func render(_ size: CGSize, scale: CGFloat = 2, _ draw: (CGContext, CGRect) -> Void) -> UIImage {
        let f = UIGraphicsImageRendererFormat()
        f.scale = scale
        f.opaque = false
        return UIGraphicsImageRenderer(size: size, format: f).image { draw($0.cgContext, CGRect(origin: .zero, size: size)) }
    }

    static func build() {
        images["player"] = render(CGSize(width: 120, height: 140), drawPlayer)
        images["bee"] = render(CGSize(width: 92, height: 92)) { drawBee($0, $1, body: [rgb(255, 214, 64), rgb(235, 150, 20)], eye: rgb(220, 30, 40)) }
        images["wasp"] = render(CGSize(width: 104, height: 104)) { drawBee($0, $1, body: [rgb(255, 130, 60), rgb(190, 50, 20)], eye: rgb(40, 20, 80)) }
        images["beetle"] = render(CGSize(width: 112, height: 112), drawBeetle)
        images["moth"] = render(CGSize(width: 132, height: 104), drawMoth)
        images["dragonfly"] = render(CGSize(width: 150, height: 104), drawDragonfly)
        images["mantis"] = render(CGSize(width: 340, height: 300), drawMantis)
        images["queen"] = render(CGSize(width: 400, height: 340), drawQueen)
        images["pbullet"] = render(CGSize(width: 18, height: 56), drawPlayerBullet)
        images["ebullet"] = render(CGSize(width: 32, height: 32)) { drawOrb($0, $1, inner: rgb(255, 250, 200), mid: rgb(255, 120, 40), outer: rgb(200, 20, 20, 0)) }
        images["sting"] = render(CGSize(width: 16, height: 46), drawSting)
        images["missile"] = render(CGSize(width: 24, height: 56), drawMissile)
        images["glow"] = render(CGSize(width: 48, height: 48)) { drawOrb($0, $1, inner: .white, mid: rgb(255, 255, 255, 0.45), outer: rgb(255, 255, 255, 0)) }
        images["ring"] = render(CGSize(width: 220, height: 220), drawRing)
        images["shield"] = render(CGSize(width: 190, height: 190), drawShield)
        images["pu0"] = render(CGSize(width: 72, height: 72)) { drawPickup($0, $1, color: rgb(255, 196, 40), glyph: 0) }
        images["pu1"] = render(CGSize(width: 72, height: 72)) { drawPickup($0, $1, color: rgb(60, 220, 255), glyph: 1) }
        images["pu2"] = render(CGSize(width: 72, height: 72)) { drawPickup($0, $1, color: rgb(255, 80, 80), glyph: 2) }
        images["pu3"] = render(CGSize(width: 72, height: 72)) { drawPickup($0, $1, color: rgb(90, 230, 110), glyph: 3) }
        images["life"] = render(CGSize(width: 40, height: 46)) { ctx, r in drawPlayer(ctx, r) }
        images["bomb"] = render(CGSize(width: 40, height: 40)) { drawPickup($0, $1, color: rgb(255, 80, 80), glyph: 2) }
        atlas = SKTextureAtlas(dictionary: images as [String: Any])
        for k in images.keys { tex[k] = atlas?.textureNamed(k) }
        atlas?.preload {}
        tex["sky"] = SKTexture(image: render(CGSize(width: 1920, height: 1080), scale: 1, drawSky))
        tex["leaves"] = SKTexture(image: render(CGSize(width: 1920, height: 1080), scale: 1, drawLeaves))
        tex["dust"] = SKTexture(image: render(CGSize(width: 1920, height: 1080), scale: 1, drawDust))
    }

    // MARK: helpers

    static func lin(_ ctx: CGContext, _ rect: CGRect, _ colors: [UIColor], vertical: Bool = true) {
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map { $0.cgColor } as CFArray, locations: nil)!
        let end = vertical ? CGPoint(x: rect.minX, y: rect.maxY) : CGPoint(x: rect.maxX, y: rect.minY)
        ctx.drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.minY), end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    static func gradEllipse(_ ctx: CGContext, _ rect: CGRect, _ colors: [UIColor], vertical: Bool = true) {
        ctx.saveGState(); ctx.addEllipse(in: rect); ctx.clip(); lin(ctx, rect, colors, vertical: vertical); ctx.restoreGState()
    }

    static func radial(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, _ colors: [UIColor]) {
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map { $0.cgColor } as CFArray, locations: nil)!
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
    }

    static func line(_ ctx: CGContext, _ a: CGPoint, _ b: CGPoint, _ c: UIColor, _ w: CGFloat) {
        ctx.setStrokeColor(c.cgColor); ctx.setLineWidth(w); ctx.setLineCap(.round)
        ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
    }

    static func poly(_ ctx: CGContext, _ pts: [CGPoint], fill: UIColor, stroke: UIColor? = nil, width: CGFloat = 1.5) {
        ctx.beginPath(); ctx.move(to: pts[0]); for p in pts.dropFirst() { ctx.addLine(to: p) }; ctx.closePath()
        ctx.setFillColor(fill.cgColor)
        if let s = stroke { ctx.setStrokeColor(s.cgColor); ctx.setLineWidth(width); ctx.drawPath(using: .fillStroke) } else { ctx.fillPath() }
    }

    static func wing(_ ctx: CGContext, _ p: CGPoint, _ w: CGFloat, _ h: CGFloat, _ angle: CGFloat, _ fill: UIColor, _ stroke: UIColor) {
        ctx.saveGState(); ctx.translateBy(x: p.x, y: p.y); ctx.rotate(by: angle)
        let r = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
        ctx.setFillColor(fill.cgColor); ctx.fillEllipse(in: r)
        ctx.setStrokeColor(stroke.cgColor); ctx.setLineWidth(1.6); ctx.strokeEllipse(in: r)
        ctx.restoreGState()
    }

    static func eye(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, _ color: UIColor) {
        gradEllipse(ctx, CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), [color.withAlphaComponent(1), color.withAlphaComponent(0.55)])
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.45, y: c.y - r * 0.55, width: r * 0.5, height: r * 0.5))
    }

    // MARK: player: an armoured beetle-gunship

    static func drawPlayer(_ ctx: CGContext, _ r: CGRect) {
        let cx = r.width / 2, sx = r.width / 120, sy = r.height / 140
        ctx.saveGState(); ctx.scaleBy(x: sx, y: sy)
        let wingFill = rgb(80, 220, 255, 0.45), wingEdge = rgb(190, 250, 255, 0.95)
        poly(ctx, [CGPoint(x: cx - 14, y: 62), CGPoint(x: 4, y: 108), CGPoint(x: 24, y: 126), CGPoint(x: cx - 12, y: 104)], fill: wingFill, stroke: wingEdge)
        poly(ctx, [CGPoint(x: cx + 14, y: 62), CGPoint(x: 116, y: 108), CGPoint(x: 96, y: 126), CGPoint(x: cx + 12, y: 104)], fill: wingFill, stroke: wingEdge)
        ctx.setShadow(offset: .zero, blur: 10, color: rgb(255, 150, 40, 0.9).cgColor)
        radial(ctx, CGPoint(x: cx, y: 130), 15, [rgb(255, 240, 160), rgb(255, 120, 30, 0.7), rgb(255, 80, 0, 0)])
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        for dx in [-27.0, 27.0] {
            let rc = CGRect(x: cx + CGFloat(dx) - 5, y: 38, width: 10, height: 52)
            ctx.setFillColor(rgb(60, 78, 92).cgColor); ctx.fill(rc)
            ctx.setFillColor(rgb(255, 170, 60).cgColor); ctx.fill(CGRect(x: rc.minX + 1, y: 34, width: 8, height: 6))
        }
        gradEllipse(ctx, CGRect(x: cx - 20, y: 22, width: 40, height: 100), [rgb(70, 215, 190), rgb(20, 90, 110)], vertical: false)
        ctx.setStrokeColor(rgb(10, 50, 60).cgColor); ctx.setLineWidth(1.5); ctx.strokeEllipse(in: CGRect(x: cx - 20, y: 22, width: 40, height: 100))
        line(ctx, CGPoint(x: cx, y: 70), CGPoint(x: cx, y: 120), rgb(10, 50, 60, 0.7), 1.6)
        gradEllipse(ctx, CGRect(x: cx - 12, y: 6, width: 24, height: 34), [rgb(120, 245, 215), rgb(30, 130, 140)])
        line(ctx, CGPoint(x: cx - 6, y: 8), CGPoint(x: cx - 16, y: -2), rgb(190, 250, 235), 2)
        line(ctx, CGPoint(x: cx + 6, y: 8), CGPoint(x: cx + 16, y: -2), rgb(190, 250, 235), 2)
        radial(ctx, CGPoint(x: cx, y: 56), 13, [.white, rgb(120, 230, 255), rgb(40, 140, 220, 0.9)])
        ctx.restoreGState()
    }

    // MARK: enemies (they face downwards)

    static func drawBee(_ ctx: CGContext, _ r: CGRect, body: [UIColor], eye eyeColor: UIColor) {
        let cx = r.width / 2, s = r.width / 92
        ctx.saveGState(); ctx.scaleBy(x: s, y: s)
        wing(ctx, CGPoint(x: cx - 26, y: 52), 44, 20, -0.6, rgb(255, 255, 255, 0.5), rgb(255, 255, 255, 0.9))
        wing(ctx, CGPoint(x: cx + 26, y: 52), 44, 20, 0.6, rgb(255, 255, 255, 0.5), rgb(255, 255, 255, 0.9))
        let ab = CGRect(x: cx - 20, y: 6, width: 40, height: 56)
        gradEllipse(ctx, ab, body, vertical: false)
        ctx.saveGState(); ctx.addEllipse(in: ab); ctx.clip()
        ctx.setFillColor(rgb(30, 22, 20).cgColor)
        for y in [18.0, 31.0, 44.0] { ctx.fill(CGRect(x: ab.minX, y: CGFloat(y), width: ab.width, height: 6)) }
        ctx.restoreGState()
        poly(ctx, [CGPoint(x: cx - 4, y: 8), CGPoint(x: cx, y: -2), CGPoint(x: cx + 4, y: 8)], fill: rgb(40, 30, 28))
        gradEllipse(ctx, CGRect(x: cx - 14, y: 52, width: 28, height: 22), [rgb(70, 50, 40), rgb(30, 22, 20)])
        gradEllipse(ctx, CGRect(x: cx - 15, y: 66, width: 30, height: 24), [rgb(255, 200, 80), rgb(210, 120, 30)])
        eye(ctx, CGPoint(x: cx - 8, y: 77), 6, eyeColor); eye(ctx, CGPoint(x: cx + 8, y: 77), 6, eyeColor)
        line(ctx, CGPoint(x: cx - 6, y: 88), CGPoint(x: cx - 14, y: 92), rgb(40, 30, 28), 1.8)
        line(ctx, CGPoint(x: cx + 6, y: 88), CGPoint(x: cx + 14, y: 92), rgb(40, 30, 28), 1.8)
        ctx.restoreGState()
    }

    static func drawBeetle(_ ctx: CGContext, _ r: CGRect) {
        let cx = r.width / 2, s = r.width / 112
        ctx.saveGState(); ctx.scaleBy(x: s, y: s)
        for i in 0..<3 {
            let y = 34 + CGFloat(i) * 20
            line(ctx, CGPoint(x: cx - 30, y: y), CGPoint(x: 6, y: y + 8 + CGFloat(i) * 3), rgb(30, 60, 70), 3)
            line(ctx, CGPoint(x: cx + 30, y: y), CGPoint(x: 106, y: y + 8 + CGFloat(i) * 3), rgb(30, 60, 70), 3)
        }
        let shell = CGRect(x: cx - 36, y: 6, width: 72, height: 84)
        gradEllipse(ctx, shell, [rgb(110, 210, 150), rgb(30, 110, 130), rgb(15, 50, 80)], vertical: false)
        ctx.setStrokeColor(rgb(10, 40, 50).cgColor); ctx.setLineWidth(2); ctx.strokeEllipse(in: shell)
        line(ctx, CGPoint(x: cx, y: 12), CGPoint(x: cx, y: 86), rgb(10, 40, 50), 2)
        ctx.setFillColor(rgb(255, 255, 255, 0.28).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - 26, y: 16, width: 16, height: 40))
        gradEllipse(ctx, CGRect(x: cx - 17, y: 80, width: 34, height: 26), [rgb(60, 130, 140), rgb(20, 60, 80)])
        eye(ctx, CGPoint(x: cx - 8, y: 94), 5, rgb(255, 200, 60)); eye(ctx, CGPoint(x: cx + 8, y: 94), 5, rgb(255, 200, 60))
        ctx.setStrokeColor(rgb(235, 235, 220).cgColor); ctx.setLineWidth(3); ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: cx - 6, y: 104)); ctx.addQuadCurve(to: CGPoint(x: cx - 16, y: 110), control: CGPoint(x: cx - 18, y: 104)); ctx.strokePath()
        ctx.move(to: CGPoint(x: cx + 6, y: 104)); ctx.addQuadCurve(to: CGPoint(x: cx + 16, y: 110), control: CGPoint(x: cx + 18, y: 104)); ctx.strokePath()
        ctx.restoreGState()
    }

    static func drawMoth(_ ctx: CGContext, _ r: CGRect) {
        let cx = r.width / 2
        let s = r.width / 132
        ctx.saveGState(); ctx.scaleBy(x: s, y: s)
        for side in [-1.0, 1.0] {
            let d = CGFloat(side)
            let upper = CGRect(x: cx + (d < 0 ? -64 : 0), y: 2, width: 64, height: 56)
            gradEllipse(ctx, upper, [rgb(220, 120, 255), rgb(110, 40, 170)], vertical: false)
            let lower = CGRect(x: cx + (d < 0 ? -46 : 0), y: 40, width: 46, height: 40)
            gradEllipse(ctx, lower, [rgb(255, 130, 200), rgb(140, 40, 130)], vertical: false)
            eye(ctx, CGPoint(x: cx + d * 34, y: 30), 11, rgb(255, 230, 120))
            ctx.setFillColor(rgb(40, 10, 60).cgColor)
            ctx.fillEllipse(in: CGRect(x: cx + d * 34 - 4, y: 26, width: 8, height: 8))
        }
        gradEllipse(ctx, CGRect(x: cx - 9, y: 10, width: 18, height: 66), [rgb(120, 90, 70), rgb(60, 40, 40)], vertical: false)
        gradEllipse(ctx, CGRect(x: cx - 12, y: 70, width: 24, height: 22), [rgb(150, 110, 90), rgb(70, 50, 50)])
        eye(ctx, CGPoint(x: cx - 6, y: 84), 4.5, rgb(255, 80, 80)); eye(ctx, CGPoint(x: cx + 6, y: 84), 4.5, rgb(255, 80, 80))
        line(ctx, CGPoint(x: cx - 5, y: 92), CGPoint(x: cx - 22, y: 102), rgb(120, 90, 70), 2)
        line(ctx, CGPoint(x: cx + 5, y: 92), CGPoint(x: cx + 22, y: 102), rgb(120, 90, 70), 2)
        ctx.restoreGState()
    }

    static func drawDragonfly(_ ctx: CGContext, _ r: CGRect) {
        let cx = r.width / 2, s = r.width / 150
        ctx.saveGState(); ctx.scaleBy(x: s, y: s)
        let wf = rgb(120, 240, 255, 0.4), we = rgb(200, 255, 255, 0.95)
        wing(ctx, CGPoint(x: cx - 42, y: 36), 78, 18, -0.2, wf, we); wing(ctx, CGPoint(x: cx + 42, y: 36), 78, 18, 0.2, wf, we)
        wing(ctx, CGPoint(x: cx - 40, y: 56), 70, 16, 0.18, wf, we); wing(ctx, CGPoint(x: cx + 40, y: 56), 70, 16, -0.18, wf, we)
        gradEllipse(ctx, CGRect(x: cx - 8, y: 2, width: 16, height: 86), [rgb(40, 190, 210), rgb(20, 80, 150)], vertical: false)
        ctx.setFillColor(rgb(255, 255, 255, 0.35).cgColor)
        for y in [14.0, 30.0, 46.0] { ctx.fill(CGRect(x: cx - 8, y: CGFloat(y), width: 16, height: 3)) }
        gradEllipse(ctx, CGRect(x: cx - 15, y: 78, width: 30, height: 24), [rgb(60, 220, 230), rgb(20, 110, 160)])
        eye(ctx, CGPoint(x: cx - 9, y: 90), 8, rgb(255, 90, 60)); eye(ctx, CGPoint(x: cx + 9, y: 90), 8, rgb(255, 90, 60))
        ctx.restoreGState()
    }

    static func drawMantis(_ ctx: CGContext, _ r: CGRect) {
        let cx = r.width / 2, s = r.width / 340
        ctx.saveGState(); ctx.scaleBy(x: s, y: s)
        wing(ctx, CGPoint(x: cx - 96, y: 120), 150, 60, -0.5, rgb(140, 255, 160, 0.35), rgb(190, 255, 200, 0.9))
        wing(ctx, CGPoint(x: cx + 96, y: 120), 150, 60, 0.5, rgb(140, 255, 160, 0.35), rgb(190, 255, 200, 0.9))
        for d in [-1.0, 1.0] {
            let sg = CGFloat(d)
            ctx.setStrokeColor(rgb(40, 130, 70).cgColor); ctx.setLineWidth(18); ctx.setLineCap(.round); ctx.setLineJoin(.round)
            ctx.move(to: CGPoint(x: cx + sg * 56, y: 150)); ctx.addLine(to: CGPoint(x: cx + sg * 138, y: 120)); ctx.addLine(to: CGPoint(x: cx + sg * 118, y: 230)); ctx.strokePath()
            ctx.setStrokeColor(rgb(120, 230, 150).cgColor); ctx.setLineWidth(5)
            ctx.move(to: CGPoint(x: cx + sg * 56, y: 150)); ctx.addLine(to: CGPoint(x: cx + sg * 138, y: 120)); ctx.addLine(to: CGPoint(x: cx + sg * 118, y: 230)); ctx.strokePath()
            for i in 0..<4 { let y = 150 + CGFloat(i) * 20; poly(ctx, [CGPoint(x: cx + sg * 114, y: y), CGPoint(x: cx + sg * 96, y: y + 8), CGPoint(x: cx + sg * 114, y: y + 14)], fill: rgb(230, 245, 200)) }
        }
        gradEllipse(ctx, CGRect(x: cx - 40, y: 14, width: 80, height: 160), [rgb(110, 220, 120), rgb(30, 110, 70)], vertical: false)
        ctx.setFillColor(rgb(20, 70, 50, 0.5).cgColor)
        for y in [40.0, 70.0, 100.0, 130.0] { ctx.fill(CGRect(x: cx - 34, y: CGFloat(y), width: 68, height: 4)) }
        gradEllipse(ctx, CGRect(x: cx - 32, y: 158, width: 64, height: 50), [rgb(130, 235, 140), rgb(40, 130, 80)])
        poly(ctx, [CGPoint(x: cx - 46, y: 196), CGPoint(x: cx + 46, y: 196), CGPoint(x: cx + 30, y: 266), CGPoint(x: cx, y: 286), CGPoint(x: cx - 30, y: 266)], fill: rgb(100, 215, 120), stroke: rgb(20, 80, 50), width: 2.5)
        eye(ctx, CGPoint(x: cx - 30, y: 232), 20, rgb(255, 80, 50)); eye(ctx, CGPoint(x: cx + 30, y: 232), 20, rgb(255, 80, 50))
        line(ctx, CGPoint(x: cx - 10, y: 262), CGPoint(x: cx - 28, y: 288), rgb(20, 80, 50), 3)
        line(ctx, CGPoint(x: cx + 10, y: 262), CGPoint(x: cx + 28, y: 288), rgb(20, 80, 50), 3)
        ctx.restoreGState()
    }

    static func drawQueen(_ ctx: CGContext, _ r: CGRect) {
        let cx = r.width / 2, s = r.width / 400
        ctx.saveGState(); ctx.scaleBy(x: s, y: s)
        wing(ctx, CGPoint(x: cx - 120, y: 150), 190, 80, -0.55, rgb(255, 255, 255, 0.4), rgb(255, 255, 255, 0.95))
        wing(ctx, CGPoint(x: cx + 120, y: 150), 190, 80, 0.55, rgb(255, 255, 255, 0.4), rgb(255, 255, 255, 0.95))
        wing(ctx, CGPoint(x: cx - 90, y: 210), 150, 56, -0.25, rgb(255, 255, 255, 0.32), rgb(255, 255, 255, 0.9))
        wing(ctx, CGPoint(x: cx + 90, y: 210), 150, 56, 0.25, rgb(255, 255, 255, 0.32), rgb(255, 255, 255, 0.9))
        let ab = CGRect(x: cx - 66, y: 8, width: 132, height: 190)
        gradEllipse(ctx, ab, [rgb(255, 214, 70), rgb(225, 140, 20)], vertical: false)
        ctx.saveGState(); ctx.addEllipse(in: ab); ctx.clip()
        ctx.setFillColor(rgb(35, 24, 20).cgColor)
        for y in [34.0, 68.0, 102.0, 136.0] { ctx.fill(CGRect(x: ab.minX, y: CGFloat(y), width: ab.width, height: 16)) }
        ctx.restoreGState()
        poly(ctx, [CGPoint(x: cx - 12, y: 22), CGPoint(x: cx, y: -4), CGPoint(x: cx + 12, y: 22)], fill: rgb(60, 40, 30))
        gradEllipse(ctx, CGRect(x: cx - 44, y: 186, width: 88, height: 60), [rgb(90, 64, 48), rgb(40, 28, 24)])
        let head = CGRect(x: cx - 52, y: 236, width: 104, height: 84)
        gradEllipse(ctx, head, [rgb(255, 205, 90), rgb(215, 130, 40)])
        eye(ctx, CGPoint(x: cx - 26, y: 282), 17, rgb(210, 40, 70)); eye(ctx, CGPoint(x: cx + 26, y: 282), 17, rgb(210, 40, 70))
        for i in 0..<5 {
            let a = -0.9 + CGFloat(i) * 0.45
            line(ctx, CGPoint(x: cx + sin(a) * 30, y: 240), CGPoint(x: cx + sin(a) * 74, y: 240 - cos(a) * 52 + 40), rgb(255, 235, 140), 4)
        }
        line(ctx, CGPoint(x: cx - 14, y: 314), CGPoint(x: cx - 40, y: 336), rgb(60, 40, 30), 4)
        line(ctx, CGPoint(x: cx + 14, y: 314), CGPoint(x: cx + 40, y: 336), rgb(60, 40, 30), 4)
        ctx.restoreGState()
    }

    // MARK: projectiles / pickups / effects

    static func drawOrb(_ ctx: CGContext, _ r: CGRect, inner: UIColor, mid: UIColor, outer: UIColor) {
        radial(ctx, CGPoint(x: r.midX, y: r.midY), r.width / 2, [inner, mid, outer])
    }

    static func drawPlayerBullet(_ ctx: CGContext, _ r: CGRect) {
        ctx.setShadow(offset: .zero, blur: 6, color: rgb(80, 240, 255).cgColor)
        let cap = r.insetBy(dx: 4, dy: 4)
        gradEllipse(ctx, cap, [rgb(255, 255, 255), rgb(90, 235, 255), rgb(40, 160, 255)])
    }

    static func drawSting(_ ctx: CGContext, _ r: CGRect) {
        ctx.setShadow(offset: .zero, blur: 4, color: rgb(170, 255, 90).cgColor)
        poly(ctx, [CGPoint(x: r.midX, y: r.maxY - 2), CGPoint(x: r.midX + 5, y: 8), CGPoint(x: r.midX, y: 2), CGPoint(x: r.midX - 5, y: 8)], fill: rgb(190, 255, 110))
    }

    static func drawMissile(_ ctx: CGContext, _ r: CGRect) {
        poly(ctx, [CGPoint(x: r.midX, y: r.maxY - 2), CGPoint(x: r.midX + 8, y: 14), CGPoint(x: r.midX - 8, y: 14)], fill: rgb(240, 240, 255), stroke: rgb(120, 160, 200))
        ctx.setFillColor(rgb(255, 150, 40).cgColor); ctx.fill(CGRect(x: r.midX - 7, y: 4, width: 14, height: 12))
        ctx.setShadow(offset: .zero, blur: 8, color: rgb(255, 160, 40).cgColor)
        ctx.setFillColor(rgb(255, 230, 120).cgColor); ctx.fillEllipse(in: CGRect(x: r.midX - 4, y: 0, width: 8, height: 10))
    }

    static func drawRing(_ ctx: CGContext, _ r: CGRect) {
        ctx.setShadow(offset: .zero, blur: 10, color: UIColor.white.cgColor)
        ctx.setStrokeColor(UIColor.white.cgColor); ctx.setLineWidth(8)
        ctx.strokeEllipse(in: r.insetBy(dx: 18, dy: 18))
    }

    static func drawShield(_ ctx: CGContext, _ r: CGRect) {
        radial(ctx, CGPoint(x: r.midX, y: r.midY), r.width / 2, [rgb(80, 220, 255, 0.0), rgb(80, 220, 255, 0.10), rgb(120, 240, 255, 0.55)])
        ctx.setStrokeColor(rgb(190, 250, 255, 0.95).cgColor); ctx.setLineWidth(4)
        ctx.strokeEllipse(in: r.insetBy(dx: 6, dy: 6))
    }

    static func drawPickup(_ ctx: CGContext, _ r: CGRect, color: UIColor, glyph: Int) {
        let c = CGPoint(x: r.midX, y: r.midY), R = r.width / 2
        radial(ctx, c, R, [color.withAlphaComponent(0.9), color.withAlphaComponent(0.55), color.withAlphaComponent(0)])
        let core = r.insetBy(dx: R * 0.28, dy: R * 0.28)
        gradEllipse(ctx, core, [UIColor.white, color])
        ctx.setStrokeColor(UIColor.white.cgColor); ctx.setLineWidth(R * 0.07); ctx.strokeEllipse(in: core)
        ctx.setStrokeColor(rgb(30, 30, 50, 0.9).cgColor); ctx.setFillColor(rgb(30, 30, 50, 0.9).cgColor); ctx.setLineWidth(R * 0.09); ctx.setLineCap(.round)
        let u = R * 0.18
        switch glyph {
        case 0:
            for dy in [-u * 0.5, u * 0.7] {
                ctx.move(to: CGPoint(x: c.x - u, y: c.y + CGFloat(dy) + u * 0.5)); ctx.addLine(to: CGPoint(x: c.x, y: c.y + CGFloat(dy) - u * 0.5)); ctx.addLine(to: CGPoint(x: c.x + u, y: c.y + CGFloat(dy) + u * 0.5)); ctx.strokePath()
            }
        case 1:
            ctx.strokeEllipse(in: CGRect(x: c.x - u * 1.1, y: c.y - u * 1.1, width: u * 2.2, height: u * 2.2))
        case 2:
            for i in 0..<8 { let a = CGFloat(i) * .pi / 4; ctx.move(to: c); ctx.addLine(to: CGPoint(x: c.x + cos(a) * u * 1.5, y: c.y + sin(a) * u * 1.5)); ctx.strokePath() }
        default:
            ctx.move(to: CGPoint(x: c.x - u * 1.2, y: c.y)); ctx.addLine(to: CGPoint(x: c.x + u * 1.2, y: c.y)); ctx.strokePath()
            ctx.move(to: CGPoint(x: c.x, y: c.y - u * 1.2)); ctx.addLine(to: CGPoint(x: c.x, y: c.y + u * 1.2)); ctx.strokePath()
        }
    }

    // MARK: backgrounds

    static func drawSky(_ ctx: CGContext, _ r: CGRect) {
        lin(ctx, r, [rgb(6, 14, 30), rgb(8, 36, 44), rgb(14, 58, 52)])
        var rng = SeededRNG(seed: 11)
        for _ in 0..<14 {
            let c = CGPoint(x: rng.next() * r.width, y: rng.next() * r.height)
            let rad = 220 + rng.next() * 380
            let hue = rng.next()
            let col = hue < 0.5 ? rgb(40, 140, 120, 0.16) : rgb(90, 70, 170, 0.14)
            radial(ctx, c, rad, [col, col.withAlphaComponent(0)])
        }
        radial(ctx, CGPoint(x: r.midX, y: r.maxY + 200), 1100, [rgb(255, 170, 60, 0.20), rgb(255, 170, 60, 0)])
        radial(ctx, CGPoint(x: r.midX, y: r.midY), 1300, [rgb(0, 0, 0, 0), rgb(0, 0, 0, 0.55)])
    }

    static func drawLeaves(_ ctx: CGContext, _ r: CGRect) {
        var rng = SeededRNG(seed: 5)
        for i in 0..<34 {
            let leftSide = i % 2 == 0
            let x = leftSide ? rng.next() * 330 - 60 : r.width - rng.next() * 330 + 60
            let y = rng.next() * r.height
            let rot = (leftSide ? 0.5 : -0.5) + (rng.next() - 0.5) * 1.2
            let w = 40 + rng.next() * 60, h = 180 + rng.next() * 240
            for dy in [-r.height, 0, r.height] {          // wrap vertically so the scrolling tile has no seam
                ctx.saveGState(); ctx.translateBy(x: x, y: y + dy); ctx.rotate(by: rot)
                let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
                gradEllipse(ctx, rect, [rgb(10, 52, 40, 0.85), rgb(6, 28, 28, 0.9)], vertical: false)
                line(ctx, CGPoint(x: 0, y: -h / 2), CGPoint(x: 0, y: h / 2), rgb(60, 140, 100, 0.25), 2)
                ctx.restoreGState()
            }
        }
    }

    static func drawDust(_ ctx: CGContext, _ r: CGRect) {
        var rng = SeededRNG(seed: 21)
        for _ in 0..<150 {
            let x = rng.next() * r.width, y = rng.next() * r.height
            let rad = 1 + rng.next() * 2.6
            let warm = rng.next() < 0.45
            let c = warm ? rgb(255, 230, 140, 0.85) : rgb(170, 255, 230, 0.7)
            for dy in [-r.height, 0, r.height] { radial(ctx, CGPoint(x: x, y: y + dy), rad * 4, [c, c.withAlphaComponent(0)]) }
        }
    }
}

struct SeededRNG {
    var s: UInt64
    init(seed: UInt64) { s = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((s >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
    }
}

import AVFoundation

// Every sound effect and the music loop are synthesized at launch (original audio, no sampled assets).
final class Sound {
    static let shared = Sound()
    private let engine = AVAudioEngine()
    private let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)!
    private var voices: [AVAudioPlayerNode] = []
    private var next = 0
    private var bufs: [String: AVAudioPCMBuffer] = [:]
    private let music = AVAudioPlayerNode()
    private var started = false
    private let sr = 44100.0

    func start() {
        guard !started else { return }
        started = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        buildEffects()
        for _ in 0..<10 {
            let n = AVAudioPlayerNode()
            engine.attach(n)
            engine.connect(n, to: engine.mainMixerNode, format: fmt)
            voices.append(n)
        }
        engine.attach(music)
        engine.connect(music, to: engine.mainMixerNode, format: fmt)
        music.volume = 0.30
        engine.mainMixerNode.outputVolume = 0.9
        do { try engine.start() } catch { started = false; return }
        voices.forEach { $0.play() }
        let m = buildMusic()
        music.scheduleBuffer(m, at: nil, options: .loops, completionHandler: nil)
        music.play()
    }

    func play(_ name: String, _ volume: Float = 1) {
        guard started, let b = bufs[name] else { return }
        let n = voices[next]
        next = (next + 1) % voices.count
        n.volume = volume
        n.scheduleBuffer(b, at: nil, options: .interrupts, completionHandler: nil)
    }

    func setMusic(_ on: Bool) { music.volume = on ? 0.30 : 0.0 }

    // MARK: synthesis

    private func make(_ dur: Double, _ f: (Double, Double) -> Float) -> AVAudioPCMBuffer {
        let n = AVAudioFrameCount(dur * sr)
        let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n)!
        b.frameLength = n
        let p = b.floatChannelData![0]
        for i in 0..<Int(n) { let t = Double(i) / sr; p[i] = f(t, t / dur) }
        return b
    }

    private func sweep(_ dur: Double, _ f0: Double, _ f1: Double, wave: Int, vol: Float, decay: Double = 2) -> AVAudioPCMBuffer {
        var phase = 0.0
        return make(dur) { _, p in
            let f = f0 + (f1 - f0) * p
            phase += 2 * Double.pi * f / self.sr
            let s: Double
            switch wave {
            case 0: s = sin(phase)
            case 1: s = sin(phase) > 0 ? 0.6 : -0.6
            default: s = 2 * (phase / (2 * Double.pi) - floor(phase / (2 * Double.pi) + 0.5))
            }
            return Float(s) * vol * Float(pow(1 - p, decay))
        }
    }

    private func noise(_ dur: Double, vol: Float, cutoff: Double, decay: Double = 2) -> AVAudioPCMBuffer {
        var y = 0.0
        var rng = SeededRNG(seed: UInt64(dur * 1000) + 7)
        return make(dur) { _, p in
            let x = Double(rng.next()) * 2 - 1
            y += cutoff * (x - y)
            return Float(y) * vol * Float(pow(1 - p, decay))
        }
    }

    private func arpeggio(_ freqs: [Double], step: Double, vol: Float) -> AVAudioPCMBuffer {
        let total = step * Double(freqs.count) + 0.12
        var phase = 0.0
        return make(total) { t, p in
            let idx = min(freqs.count - 1, Int(t / step))
            phase += 2 * Double.pi * freqs[idx] / self.sr
            let local = (t - Double(idx) * step) / step
            let env = Float(max(0, 1 - local * 0.8)) * Float(1 - p * 0.5)
            return Float(sin(phase) * 0.7 + (sin(phase * 2) * 0.2)) * vol * env
        }
    }

    private func mix(_ a: AVAudioPCMBuffer, _ b: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let n = max(a.frameLength, b.frameLength)
        let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n)!
        out.frameLength = n
        let o = out.floatChannelData![0], pa = a.floatChannelData![0], pb = b.floatChannelData![0]
        for i in 0..<Int(n) {
            o[i] = (i < Int(a.frameLength) ? pa[i] : 0) + (i < Int(b.frameLength) ? pb[i] : 0)
        }
        return out
    }

    private func buildEffects() {
        bufs["shoot"] = sweep(0.09, 1250, 420, wave: 1, vol: 0.22, decay: 1.6)
        bufs["shoot2"] = sweep(0.11, 900, 260, wave: 2, vol: 0.20, decay: 1.8)
        bufs["enemyShot"] = sweep(0.14, 520, 230, wave: 0, vol: 0.28, decay: 1.4)
        bufs["hit"] = noise(0.05, vol: 0.5, cutoff: 0.6, decay: 1.2)
        bufs["explode"] = mix(noise(0.45, vol: 0.9, cutoff: 0.18, decay: 2.2), sweep(0.3, 180, 40, wave: 0, vol: 0.7, decay: 2))
        bufs["bigExplode"] = mix(noise(1.1, vol: 1.0, cutoff: 0.09, decay: 1.8), sweep(0.9, 120, 28, wave: 0, vol: 0.9, decay: 1.5))
        bufs["pickup"] = arpeggio([660, 830, 990, 1320], step: 0.055, vol: 0.35)
        bufs["life"] = arpeggio([523, 659, 784, 1046, 1318], step: 0.07, vol: 0.4)
        bufs["bomb"] = mix(noise(0.9, vol: 0.9, cutoff: 0.25, decay: 1.4), sweep(0.8, 1400, 50, wave: 2, vol: 0.5, decay: 1.2))
        bufs["playerHit"] = mix(noise(0.6, vol: 1.0, cutoff: 0.2, decay: 1.6), sweep(0.5, 400, 60, wave: 2, vol: 0.5, decay: 1.4))
        bufs["shieldHit"] = sweep(0.25, 1600, 500, wave: 0, vol: 0.45, decay: 1.5)
        bufs["wave"] = arpeggio([392, 523, 659, 784], step: 0.09, vol: 0.4)
        bufs["boss"] = sweep(1.2, 110, 90, wave: 2, vol: 0.55, decay: 0.6)
        bufs["gameOver"] = arpeggio([392, 330, 262, 196, 131], step: 0.2, vol: 0.45)
        bufs["move"] = sweep(0.04, 800, 800, wave: 1, vol: 0.18, decay: 1)
        bufs["select"] = arpeggio([659, 988], step: 0.05, vol: 0.35)
    }

    private func buildMusic() -> AVAudioPCMBuffer {
        let bpm = 138.0, stepDur = 60.0 / bpm / 4
        let bars = 8
        let total = Double(bars * 16) * stepDur
        let n = Int(total * sr)
        var out = [Float](repeating: 0, count: n)
        func tone(_ start: Double, _ dur: Double, _ freq: Double, _ vol: Float, saw: Bool) {
            let s0 = Int(start * sr), len = Int(dur * sr)
            var phase = 0.0
            for i in 0..<len where s0 + i < n {
                phase += 2 * Double.pi * freq / sr
                let p = Double(i) / Double(len)
                let env = Float(min(1, p * 40)) * Float(pow(1 - p, 1.5))
                let w: Double = saw ? 2 * (phase / (2 * Double.pi) - floor(phase / (2 * Double.pi) + 0.5)) : (sin(phase) > 0 ? 0.55 : -0.55)
                out[s0 + i] += Float(w) * vol * env
            }
        }
        func kick(_ start: Double) {
            let s0 = Int(start * sr), len = Int(0.18 * sr)
            var phase = 0.0
            for i in 0..<len where s0 + i < n {
                let p = Double(i) / Double(len)
                phase += 2 * Double.pi * (130 - 90 * p) / sr
                out[s0 + i] += Float(sin(phase)) * 0.55 * Float(pow(1 - p, 2))
            }
        }
        var rng = SeededRNG(seed: 99)
        func hat(_ start: Double) {
            let s0 = Int(start * sr), len = Int(0.04 * sr)
            for i in 0..<len where s0 + i < n {
                let p = Float(i) / Float(len)
                out[s0 + i] += (Float(rng.next()) * 2 - 1) * 0.10 * (1 - p)
            }
        }
        let roots = [110.0, 87.31, 130.81, 98.0]
        let chords: [[Double]] = [[440, 523.25, 659.25], [349.23, 440, 523.25], [523.25, 659.25, 783.99], [392, 493.88, 587.33]]
        let arpPattern = [0, 1, 2, 1, 0, 1, 2, 1, 2, 1, 0, 1, 2, 1, 0, 1]
        for bar in 0..<bars {
            let ci = (bar / 2) % 4
            for step in 0..<16 {
                let t = (Double(bar * 16 + step)) * stepDur
                if step % 4 == 0 { kick(t) }
                if step % 2 == 1 { hat(t) }
                if step % 2 == 0 { tone(t, stepDur * 1.6, roots[ci] * (step % 8 == 4 ? 2 : 1), 0.20, saw: true) }
                let oct = bar >= 4 ? 2.0 : 1.0
                tone(t, stepDur * 0.9, chords[ci][arpPattern[step]] * oct, bar >= 4 ? 0.075 : 0.06, saw: false)
            }
        }
        let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(n))!
        b.frameLength = AVAudioFrameCount(n)
        let p = b.floatChannelData![0]
        for i in 0..<n { p[i] = max(-0.95, min(0.95, out[i])) }
        return b
    }
}

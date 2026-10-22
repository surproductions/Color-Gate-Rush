import AVFoundation
import os

/// Original sound effects and music, synthesized at launch (no audio files are bundled).
/// Uses the `.ambient` session category so the game respects the silent switch and mixes
/// politely with other apps' audio.
final class AudioManager: NSObject {
    enum Sound: CaseIterable {
        case tap, move, shard, prism, shield, shieldBreak, milestone, tierUp, crash, unlock, countdown, go, purchase
    }

    private static let sampleRate = 44_100.0
    private static let gateLevels = 5
    private let log = Logger(subsystem: "ColorGateRush", category: "audio")

    private let engine = AVAudioEngine()
    private let effectsMixer = AVAudioMixerNode()
    private let musicNode = AVAudioPlayerNode()
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0
    private let format: AVAudioFormat?

    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var gateBuffers: [AVAudioPCMBuffer] = []
    private var musicBuffer: AVAudioPCMBuffer?
    private var isMusicScheduled = false
    private var isEngineReady = false

    private(set) var soundEnabled = true
    private(set) var musicEnabled = true
    private var soundVolume: Float = 0.85
    private var musicVolume: Float = 0.6

    override init() {
        format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)
        super.init()
        configureSession()
        buildGraph()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleInterruption(_:)),
                           name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(handleConfigurationChange(_:)),
                           name: .AVAudioEngineConfigurationChange, object: engine)
        renderAssets()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    func apply(_ settings: GameSettings) {
        soundEnabled = settings.soundEnabled
        musicEnabled = settings.musicEnabled
        soundVolume = Float(settings.soundVolume)
        musicVolume = Float(settings.musicVolume)
        effectsMixer.outputVolume = soundEnabled ? soundVolume : 0
        musicNode.volume = musicVolume * 0.55
        updateMusicPlayback()
    }

    func play(_ sound: Sound) {
        guard soundEnabled, let buffer = buffers[sound] else { return }
        schedule(buffer)
    }

    /// Gate chimes rise in pitch with the combo multiplier.
    func playGate(level: Int) {
        guard soundEnabled, !gateBuffers.isEmpty else { return }
        schedule(gateBuffers[min(max(0, level), gateBuffers.count - 1)])
    }

    /// Restarts audio after the app returns to the foreground.
    func resumeAfterForeground() {
        startEngineIfNeeded()
        updateMusicPlayback()
    }

    // MARK: - Engine

    private func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            log.error("Audio session setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func buildGraph() {
        guard let format else {
            log.error("Could not create audio format; audio disabled")
            return
        }
        engine.attach(effectsMixer)
        engine.attach(musicNode)
        engine.connect(effectsMixer, to: engine.mainMixerNode, format: format)
        engine.connect(musicNode, to: engine.mainMixerNode, format: format)
        for _ in 0..<8 {
            let voice = AVAudioPlayerNode()
            engine.attach(voice)
            engine.connect(voice, to: effectsMixer, format: format)
            voices.append(voice)
        }
        engine.prepare()
        isEngineReady = true
        startEngineIfNeeded()
    }

    private func startEngineIfNeeded() {
        guard isEngineReady, !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            log.error("Audio engine failed to start: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func schedule(_ buffer: AVAudioPCMBuffer) {
        guard !voices.isEmpty else { return }
        startEngineIfNeeded()
        guard engine.isRunning else { return }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !voice.isPlaying { voice.play() }
    }

    private func updateMusicPlayback() {
        guard let musicBuffer else { return }
        if musicEnabled && musicVolume > 0 {
            startEngineIfNeeded()
            guard engine.isRunning else { return }
            if !isMusicScheduled {
                musicNode.scheduleBuffer(musicBuffer, at: nil, options: .loops, completionHandler: nil)
                isMusicScheduled = true
            }
            if !musicNode.isPlaying { musicNode.play() }
        } else if musicNode.isPlaying {
            musicNode.pause()
        }
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch type {
            case .began:
                self.musicNode.pause()
            case .ended:
                try? AVAudioSession.sharedInstance().setActive(true)
                self.resumeAfterForeground()
            @unknown default:
                break
            }
        }
    }

    @objc private func handleConfigurationChange(_ note: Notification) {
        // The engine stops itself when the route changes; player nodes lose their schedule.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isMusicScheduled = false
            self.musicNode.stop()
            self.resumeAfterForeground()
        }
    }

    // MARK: - Synthesis

    private func renderAssets() {
        guard let format else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var sounds: [Sound: AVAudioPCMBuffer] = [:]
            for sound in Sound.allCases {
                sounds[sound] = Self.buffer(Synth.render(sound), format: format)
            }
            let gates = (0..<Self.gateLevels).compactMap { Self.buffer(Synth.gate(level: $0), format: format) }
            let music = Self.buffer(Synth.music(), format: format)
            DispatchQueue.main.async {
                guard let self else { return }
                self.buffers = sounds
                self.gateBuffers = gates
                self.musicBuffer = music
                self.updateMusicPlayback()
            }
        }
    }

    private static func buffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            channel.update(from: base, count: samples.count)
        }
        return buffer
    }
}

/// Tiny additive/subtractive synthesizer used to author every sound in code.
private enum Synth {
    static let rate = 44_100.0

    /// Deterministic noise so renders are identical on every launch.
    struct Noise {
        var state: UInt32 = 0x1234_5678
        mutating func next() -> Double {
            state = state &* 1_664_525 &+ 1_013_904_223
            return Double(state) / Double(UInt32.max) * 2 - 1
        }
    }

    static func render(duration: Double, _ sample: (Double) -> Double) -> [Float] {
        let count = Int(duration * rate)
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            out[i] = Float(max(-1, min(1, sample(Double(i) / rate))))
        }
        return out
    }

    /// Attack/decay envelope.
    static func env(_ t: Double, attack: Double, decay: Double) -> Double {
        if t < attack { return t / attack }
        return max(0, exp(-(t - attack) / decay))
    }

    static func sine(_ freq: Double, _ t: Double) -> Double { sin(2 * .pi * freq * t) }

    static func tri(_ freq: Double, _ t: Double) -> Double {
        let p = (freq * t).truncatingRemainder(dividingBy: 1)
        return 4 * abs(p - 0.5) - 1
    }

    static func square(_ freq: Double, _ t: Double) -> Double {
        // Band-limited-ish square from the first three odd harmonics (softer than a pure square).
        sine(freq, t) + sine(freq * 3, t) / 3 + sine(freq * 5, t) / 5
    }

    static func note(_ semitonesFromA4: Double) -> Double { 440 * pow(2, semitonesFromA4 / 12) }

    /// Plays a sequence of tones, each starting `step` seconds after the previous.
    static func arpeggio(_ freqs: [Double], step: Double, decay: Double, gain: Double, duration: Double) -> [Float] {
        render(duration: duration) { t in
            var v = 0.0
            for (i, f) in freqs.enumerated() {
                let start = Double(i) * step
                guard t >= start else { continue }
                let local = t - start
                v += (sine(f, local) + 0.3 * sine(f * 2, local)) * env(local, attack: 0.004, decay: decay)
            }
            return v * gain
        }
    }

    static func render(_ sound: AudioManager.Sound) -> [Float] {
        switch sound {
        case .tap:
            return render(duration: 0.08) { t in sine(700 + 900 * t, t) * env(t, attack: 0.002, decay: 0.018) * 0.35 }
        case .move:
            var noise = Noise()
            return render(duration: 0.09) { t in
                let sweep = sine(320 + 1600 * t, t) * 0.5
                return (sweep + noise.next() * 0.25) * env(t, attack: 0.004, decay: 0.025) * 0.22
            }
        case .shard:
            return arpeggio([note(22), note(27)], step: 0.045, decay: 0.06, gain: 0.25, duration: 0.25)
        case .prism:
            return render(duration: 0.45) { t in
                let f = 380 * pow(2, t * 4.5)
                let vibrato = 1 + 0.01 * sine(18, t)
                return (sine(f * vibrato, t) + 0.4 * tri(f * 1.5, t)) * env(t, attack: 0.01, decay: 0.14) * 0.28
            }
        case .shield:
            return arpeggio([note(0), note(7), note(12)], step: 0.06, decay: 0.12, gain: 0.25, duration: 0.45)
        case .shieldBreak:
            var noise = Noise()
            return render(duration: 0.4) { t in
                let tone = square(260 - 300 * t, t) * 0.25
                return (tone + noise.next() * 0.6) * env(t, attack: 0.002, decay: 0.08) * 0.35
            }
        case .milestone:
            return arpeggio([note(3), note(7), note(10), note(15)], step: 0.07, decay: 0.16, gain: 0.22, duration: 0.7)
        case .tierUp:
            return arpeggio([note(-2), note(2), note(5), note(10), note(14), note(17)], step: 0.06, decay: 0.22,
                            gain: 0.2, duration: 1.0)
        case .crash:
            var noise = Noise()
            return render(duration: 0.8) { t in
                let f = max(40, 320 * exp(-t * 4))
                let body = tri(f, t) * 0.6 + noise.next() * 0.5 * exp(-t * 6)
                return body * env(t, attack: 0.002, decay: 0.25) * 0.5
            }
        case .unlock:
            return arpeggio([note(3), note(10), note(15), note(22)], step: 0.08, decay: 0.25, gain: 0.22, duration: 0.9)
        case .countdown:
            return render(duration: 0.15) { t in square(440, t) * env(t, attack: 0.003, decay: 0.05) * 0.16 }
        case .go:
            return render(duration: 0.35) { t in square(880, t) * env(t, attack: 0.003, decay: 0.12) * 0.16 }
        case .purchase:
            return arpeggio([note(10), note(15), note(19)], step: 0.05, decay: 0.12, gain: 0.24, duration: 0.45)
        }
    }

    static func gate(level: Int) -> [Float] {
        // Major-pentatonic steps so higher combos sound brighter but stay musical.
        let steps: [Double] = [3, 5, 7, 10, 12]
        let base = note(steps[min(level, steps.count - 1)])
        return arpeggio([base, base * 1.5], step: 0.045, decay: 0.09, gain: 0.24, duration: 0.3)
    }

    /// An 8-bar synthwave loop: bass, arpeggio, soft kick and hats. Am – F – C – G.
    static func music() -> [Float] {
        let bpm = 112.0
        let beat = 60 / bpm
        let bar = beat * 4
        let bars = 8
        let duration = bar * Double(bars)
        // Chord roots (semitones from A4) and triad intervals.
        let roots: [Double] = [-12, -16, -21, -14]
        let triads: [[Double]] = [[0, 3, 7], [0, 4, 7], [0, 4, 7], [0, 4, 7]]
        var noise = Noise()
        let count = Int(duration * rate)
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / rate
            let barIndex = Int(t / bar) % bars
            let chord = barIndex / 2 % roots.count
            let root = roots[chord]
            let tInBar = t.truncatingRemainder(dividingBy: bar)
            let tInBeat = t.truncatingRemainder(dividingBy: beat)

            // Bass on eighth notes.
            let eighth = beat / 2
            let tInEighth = t.truncatingRemainder(dividingBy: eighth)
            let bassFreq = note(root - 12)
            var v = tri(bassFreq, t) * env(tInEighth, attack: 0.005, decay: 0.12) * 0.32

            // Arpeggio on sixteenths.
            let sixteenth = beat / 4
            let step = Int(tInBar / sixteenth)
            let tInStep = tInBar.truncatingRemainder(dividingBy: sixteenth)
            let pattern = [0, 1, 2, 1, 0, 2, 1, 2]
            let arpNote = note(root + 12 + triads[chord][pattern[step % pattern.count]] + (step >= 8 ? 12 : 0))
            v += (sine(arpNote, t) * 0.6 + square(arpNote, t) * 0.12) * env(tInStep, attack: 0.003, decay: 0.07) * 0.18

            // Pad: quiet sustained triad.
            for interval in triads[chord] {
                v += sine(note(root + interval), t) * 0.025
            }

            // Kick on every beat, hat on off-beats.
            let kickFreq = 50 + 90 * exp(-tInBeat * 30)
            v += sine(kickFreq, tInBeat) * env(tInBeat, attack: 0.001, decay: 0.09) * 0.45
            let tOff = (t + beat / 2).truncatingRemainder(dividingBy: beat)
            v += noise.next() * env(tOff, attack: 0.001, decay: 0.018) * 0.08

            out[i] = Float(max(-1, min(1, v * 0.8)))
        }
        // Short fades at the loop seam to avoid clicks.
        let fade = Int(0.01 * rate)
        for i in 0..<min(fade, count) {
            let g = Float(i) / Float(fade)
            out[i] *= g
            out[count - 1 - i] *= g
        }
        return out
    }
}

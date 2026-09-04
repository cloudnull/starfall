import AVFoundation
import StarfallCore

/// Procedural audio engine using AVFoundation.
///
/// All sounds and music are synthesized at runtime — no external assets required.
/// The engine creates audio buffers from waveform generators and plays them
/// through an AVAudioEngine graph.
@MainActor
public final class AudioEngine {
    private let engine: AVAudioEngine
    private let mixer: AVAudioMixerNode
    private let sfxMixer: AVAudioMixerNode
    private let musicMixer: AVAudioMixerNode

    private var musicPlayer: AVAudioPlayerNode?
    private var currentMusicTrack: MusicTrack?
    private var aliveBuffers: [AVAudioPCMBuffer] = []

    public init() {
        engine = AVAudioEngine()
        mixer = engine.mainMixerNode
        sfxMixer = AVAudioMixerNode()
        musicMixer = AVAudioMixerNode()

        engine.attach(sfxMixer)
        engine.attach(musicMixer)

        engine.connect(sfxMixer, to: mixer, format: nil)
        engine.connect(musicMixer, to: mixer, format: nil)

        // Restore persisted settings. First launch uses the defaults below.
        let defaults = UserDefaults.standard
        sfxVolume = defaults.object(forKey: DefaultsKey.sfxVolume) as? Float ?? 0.5
        musicVolume = defaults.object(forKey: DefaultsKey.musicVolume) as? Float ?? 0.3
        // Start with audio muted to avoid audio thread crashes during init.
        // Audio is enabled lazily on first use.
        isMuted = true
        if defaults.object(forKey: DefaultsKey.isMuted) != nil {
            isMuted = defaults.bool(forKey: DefaultsKey.isMuted)
        }
    }

    private enum DefaultsKey {
        static let sfxVolume = "settings.sfxVolume"
        static let musicVolume = "settings.musicVolume"
        static let isMuted = "settings.isMuted"
    }

    public var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: DefaultsKey.isMuted) }
    }

    public var sfxVolume: Float {
        didSet { UserDefaults.standard.set(sfxVolume, forKey: DefaultsKey.sfxVolume) }
    }

    public var musicVolume: Float {
        didSet { UserDefaults.standard.set(musicVolume, forKey: DefaultsKey.musicVolume) }
    }

    private func ensureStarted() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
            // Enable audio after the engine is running.
            isMuted = false
        } catch {
            // Audio session may already be active or unavailable; non-fatal.
        }
    }

    private func effectiveSfxVolume() -> Float {
        isMuted ? 0 : sfxVolume
    }

    private func effectiveMusicVolume() -> Float {
        isMuted ? 0 : musicVolume
    }

    // MARK: - Sound Effects

    /// Play a one-shot sound effect. Volume is baked into the buffer samples.
    public func play(_ effect: SoundEffect) {
        ensureStarted()

        let sampleRate = mixer.outputFormat(forBus: 0).sampleRate
        guard var buffer = SoundSynthesizer.generate(effect, format: sampleRate) else { return }

        // Apply volume to the buffer samples.
        applyVolume(&buffer, volume: effectiveSfxVolume())

        // Keep the buffer alive for the duration of playback. Cap the array to prevent growth.
        aliveBuffers.append(buffer)
        if aliveBuffers.count > 64 {
            aliveBuffers.removeFirst(aliveBuffers.count - 32)
        }

        // Create a fresh player per SFX to avoid format mismatch on pre-connected nodes.
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: sfxMixer, format: buffer.format)
        if player.isPlaying { player.stop() }
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    // MARK: - Music

    /// Start playing a music track (loops). Stops any currently playing track.
    public func playMusic(_ track: MusicTrack) {
        stopMusic()
        currentMusicTrack = track
        ensureStarted()

        let sampleRate = mixer.outputFormat(forBus: 0).sampleRate
        guard var buffer = MusicSynthesizer.generate(track, format: sampleRate) else { return }

        applyVolume(&buffer, volume: effectiveMusicVolume())
        aliveBuffers.append(buffer)

        let player = AVAudioPlayerNode()
        musicPlayer = player
        engine.attach(player)
        engine.connect(player, to: musicMixer, format: buffer.format)
        player.scheduleBuffer(buffer, at: nil, options: [.loops])
        player.play()
    }

    /// Stop the currently playing music track.
    public func stopMusic() {
        musicPlayer?.stop()
        if let mp = musicPlayer {
            engine.disconnectNodeInput(mp)
            engine.detach(mp)
        }
        musicPlayer = nil
        currentMusicTrack = nil
        aliveBuffers.removeAll()
    }

    /// Change the music track, or stop if the new track matches the current one (toggle off).
    public func setMusic(_ track: MusicTrack?) {
        if let track {
            if currentMusicTrack == track {
                stopMusic()
            } else {
                playMusic(track)
            }
        } else {
            stopMusic()
        }
    }

    // MARK: - Helpers

    /// Multiply buffer samples by a volume factor in-place.
    private func applyVolume(_ buffer: inout AVAudioPCMBuffer, volume: Float) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        for channel in 0..<channels {
            let ptr = channelData[channel]
            for i in 0..<frameCount {
                ptr[i] *= volume
            }
        }
    }
}
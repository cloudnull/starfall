import AVFoundation
import StarfallCore

/// Generates looping music buffers procedurally.
///
/// Each track is a short loop (2-4 seconds) with layered oscillators
/// that repeat seamlessly. No external audio files needed.
final class MusicSynthesizer {
    
    static func generate(_ track: MusicTrack, format sampleRate: Double) -> AVAudioPCMBuffer? {
        let (duration, layers) = trackConfig(track)
        let frameCount = Int(Double(sampleRate) * duration)
        guard frameCount > 0 else { return nil }
        
let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                     sampleRate: sampleRate,
                                     channels: 2,
                                     interleaved: false)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: AVAudioFrameCount(frameCount)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        guard let channelData = buffer.floatChannelData else { return nil }
        let leftChannel = channelData[0]
        let rightChannel = channelData[1]
        let dt = 1.0 / sampleRate
        
        let rng = SeededRNG(seed: trackHash(track))
        var melodicNoteIndex = 0
        var lastNoteTime = -1.0
        
        for i in 0..<frameCount {
            let time = Double(i) * dt
            var leftSum: Float = 0
            var rightSum: Float = 0
            
            // Per-note sequencing: pick a new note every N seconds.
            let noteDuration = layers.noteDuration
            if time - lastNoteTime >= noteDuration {
                melodicNoteIndex = rng.nextInt(upperBound: layers.melody.count)
                lastNoteTime = time
            }
            let currentFreq = layers.melody[melodicNoteIndex]
            
            for layer in layers.layers {
                let freq: Double
                let waveType: Int
                
                switch layer.type {
                case .drone:
                    freq = layer.baseFreq
                    waveType = 0 // sine
                case .bass:
                    freq = layer.baseFreq
                    waveType = 1 // triangle-ish
                case .melody:
                    freq = currentFreq * layer.detune
                    waveType = 2 // square-ish
                case .arpeggio:
                    let arpSpeed = layer.baseFreq // repurposed as speed multiplier
                    let arpIndex = Int(time * arpSpeed) % 4
                    let arpNotes: [Double] = [1, 1.25, 1.5, 2]
                    freq = layer.detune * arpNotes[arpIndex]
                    waveType = 3 // pulse
                case .atmosphere:
                    let slowOsc = sin(2 * .pi * 0.1 * time)
                    freq = layer.baseFreq + slowOsc * 5
                    waveType = 0 // sine
                }
                
                // Loop envelope: crossfade at boundaries for seamless loop.
                let loopPos = time / duration
                let loopEnv = smoothstep(loopPos)
                
                // Waveform synthesis.
                let wave: Double
                switch waveType {
                case 0:
                    wave = sin(2 * .pi * freq * time)
                case 1:
                    // Triangle-ish
                    let phase = (freq * time).truncatingRemainder(dividingBy: 1)
                    wave = 4 * abs(phase - 0.5) - 1
                case 2:
                    // Soft square
                    let phase = (freq * time).truncatingRemainder(dividingBy: 1)
                    wave = phase < 0.5 ? 0.6 : -0.6
                case 3:
                    // Pulse (33% duty)
                    let phase = (freq * time).truncatingRemainder(dividingBy: 1)
                    wave = phase < 0.33 ? 0.4 : -0.4
                default:
                    wave = sin(2 * .pi * freq * time)
                }
                
                // Stereo spread.
                let pan = layer.pan
                let lGain = cos(.pi * 0.5 * pan)
                let rGain = sin(.pi * 0.5 * pan)
                
                leftSum += Float(wave * layer.volume * lGain * loopEnv)
                rightSum += Float(wave * layer.volume * rGain * loopEnv)
            }
            
            // Limit to prevent clipping.
            let maxSample: Float = 0.8
            leftSum = max(-maxSample, min(maxSample, leftSum))
            rightSum = max(-maxSample, min(maxSample, rightSum))
            
            // Interleaved stereo: even = left, odd = right.
            leftChannel[i] = leftSum
            rightChannel[i] = rightSum
        }
        
        return buffer
    }
    
    // MARK: - Track Configurations
    
    private static func trackConfig(_ track: MusicTrack) -> (duration: Double, layers: LayerGroup) {
        switch track {
        case .menu:
            return (
                duration: 4.0,
                layers: LayerGroup(
                    noteDuration: 0.5,
                    melody: [261.63, 329.63, 392.00, 523.25, 440.00, 349.23, 329.63, 293.66],
                    layers: [
                        Layer(type: .drone, baseFreq: 130.81, detune: 1, volume: 0.15, pan: 0),
                        Layer(type: .bass, baseFreq: 65.41, detune: 1, volume: 0.12, pan: 0),
                        Layer(type: .melody, baseFreq: 1, detune: 1, volume: 0.1, pan: 0.3),
                        Layer(type: .atmosphere, baseFreq: 196.00, detune: 1, volume: 0.05, pan: -0.5),
                    ]
                )
            )
            
        case .combat:
            return (
                duration: 3.0,
                layers: LayerGroup(
                    noteDuration: 0.25,
                    melody: [220.00, 261.63, 329.63, 392.00, 440.00, 392.00, 349.23, 329.63, 293.66, 261.63, 246.94, 220.00],
                    layers: [
                        Layer(type: .drone, baseFreq: 110.00, detune: 1, volume: 0.12, pan: 0),
                        Layer(type: .bass, baseFreq: 55.00, detune: 1, volume: 0.15, pan: 0),
                        Layer(type: .melody, baseFreq: 1, detune: 1, volume: 0.1, pan: 0.4),
                        Layer(type: .arpeggio, baseFreq: 6, detune: 440, volume: 0.06, pan: -0.3),
                        Layer(type: .atmosphere, baseFreq: 164.81, detune: 1, volume: 0.04, pan: 0.6),
                    ]
                )
            )
            
        case .campaign:
            return (
                duration: 4.0,
                layers: LayerGroup(
                    noteDuration: 0.75,
                    melody: [261.63, 293.66, 329.63, 349.23, 392.00, 349.23, 329.63, 293.66, 261.63, 246.94, 220.00, 246.94],
                    layers: [
                        Layer(type: .drone, baseFreq: 130.81, detune: 1, volume: 0.1, pan: 0),
                        Layer(type: .bass, baseFreq: 65.41, detune: 1, volume: 0.1, pan: 0),
                        Layer(type: .melody, baseFreq: 1, detune: 1, volume: 0.12, pan: 0.2),
                        Layer(type: .arpeggio, baseFreq: 3, detune: 261.63, volume: 0.05, pan: -0.4),
                    ]
                )
            )
            
        case .victory:
            return (
                duration: 3.0,
                layers: LayerGroup(
                    noteDuration: 0.35,
                    melody: [523.25, 587.33, 659.25, 698.46, 783.99, 880.00, 783.99, 698.46, 659.25, 783.99, 880.00, 1046.50],
                    layers: [
                        Layer(type: .drone, baseFreq: 261.63, detune: 1, volume: 0.1, pan: 0),
                        Layer(type: .bass, baseFreq: 130.81, detune: 1, volume: 0.12, pan: 0),
                        Layer(type: .melody, baseFreq: 1, detune: 1, volume: 0.12, pan: 0.3),
                        Layer(type: .arpeggio, baseFreq: 8, detune: 523.25, volume: 0.06, pan: -0.5),
                    ]
                )
            )
            
        case .defeat:
            return (
                duration: 4.0,
                layers: LayerGroup(
                    noteDuration: 0.5,
                    melody: [349.23, 329.63, 293.66, 261.63, 246.94, 220.00, 196.00, 220.00, 196.00, 174.61, 164.81, 146.83],
                    layers: [
                        Layer(type: .drone, baseFreq: 110.00, detune: 1, volume: 0.1, pan: 0),
                        Layer(type: .bass, baseFreq: 55.00, detune: 1, volume: 0.12, pan: 0),
                        Layer(type: .melody, baseFreq: 1, detune: 1, volume: 0.1, pan: -0.2),
                        Layer(type: .atmosphere, baseFreq: 164.81, detune: 1, volume: 0.06, pan: 0.4),
                    ]
                )
            )
        }
    }
    
    private static func trackHash(_ track: MusicTrack) -> UInt64 {
        switch track {
        case .menu: return 1001
        case .combat: return 1002
        case .campaign: return 1003
        case .victory: return 1004
        case .defeat: return 1005
        }
    }
    
    private static func smoothstep(_ t: Double) -> Double {
        // Crossfade envelope: fade in at start, fade out at end.
        let fadeIn = min(1.0, t * 20)
        let fadeOut = min(1.0, (1.0 - t) * 20)
        return fadeIn * fadeOut
    }
    
    // MARK: - Layer Types
    
    private enum LayerType {
        case drone
        case bass
        case melody
        case arpeggio
        case atmosphere
    }
    
    private struct Layer {
        let type: LayerType
        let baseFreq: Double
        let detune: Double
        let volume: Double
        let pan: Double // -1 to 1
    }
    
    private struct LayerGroup {
        let noteDuration: Double
        let melody: [Double]
        let layers: [Layer]
    }
}
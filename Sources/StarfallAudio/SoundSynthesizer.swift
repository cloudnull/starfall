import AVFoundation
import StarfallCore

/// Generates one-shot audio buffers for sound effects.
///
/// Each effect is a short synthesized waveform — no external audio files needed.
final class SoundSynthesizer {
    
    static func generate(_ effect: SoundEffect, format sampleRate: Double) -> AVAudioPCMBuffer? {
        let duration: Double
        let generator: (Int, Double, Double) -> Double
        
        switch effect {
        case .weaponFire:
            duration = 0.08
            generator = { frame, time, sr in
                let env = exp(-Double(frame) / (sr * 0.03))
                let tone = sin(2 * .pi * 800 * time)
                let noise = (Double(arc4random()) / 4294967295.0 - 0.5) * 0.6
                return env * (tone * 0.5 + noise)
            }
            
        case .impact:
            duration = 0.12
            generator = { frame, time, sr in
                let env = exp(-Double(frame) / (sr * 0.05))
                let tone = sin(2 * .pi * 200 * time) * 0.7
                let sub = sin(2 * .pi * 80 * time) * 0.5
                return env * (tone + sub)
            }
            
        case .explosion:
            duration = 0.5
            generator = { frame, time, sr in
                let env = exp(-Double(frame) / (sr * 0.2))
                let noise = (Double(arc4random()) / 4294967295.0 - 0.5)
                let rumble = sin(2 * .pi * 60 * time) * 0.4
                return env * (noise * 0.7 + rumble)
            }
            
        case .thruster:
            duration = 0.1
            generator = { frame, time, sr in
                let env = min(1.0, Double(frame) / (sr * 0.02)) * exp(-Double(frame) / (sr * 0.08))
                let rumble = sin(2 * .pi * 120 * time) * 0.3
                let noise = (Double(arc4random()) / 4294967295.0 - 0.5) * 0.4
                return env * (rumble + noise)
            }
            
        case .uiClick:
            duration = 0.05
            generator = { frame, time, sr in
                let env = exp(-Double(frame) / (sr * 0.015))
                return env * sin(2 * .pi * 1200 * time)
            }
            
        case .victory:
            duration = 0.6
            generator = { frame, time, sr in
                let env = exp(-Double(frame) / (sr * 0.4))
                let notes: [Double] = [523.25, 659.25, 783.99, 1046.50]
                let idx = min(notes.count - 1, Int(time * 4))
                let freq = notes[idx]
                return env * sin(2 * .pi * freq * time) * 0.6
            }
            
        case .defeat:
            duration = 0.8
            generator = { frame, time, sr in
                let env = exp(-Double(frame) / (sr * 0.5))
                let notes: [Double] = [400, 350, 300, 200]
                let idx = min(notes.count - 1, Int(time * 3))
                let freq = notes[idx]
                return env * sin(2 * .pi * freq * time) * 0.5
            }
        }
        
        let frameCount = Int(Double(sampleRate) * duration)
        guard frameCount > 0 else { return nil }
        
let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                     sampleRate: sampleRate,
                                     channels: 1,
                                     interleaved: false)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: AVAudioFrameCount(frameCount)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        guard let channelData = buffer.floatChannelData else { return nil }
        let samples = channelData[0]
        let dt = 1.0 / sampleRate
        
        for i in 0..<frameCount {
            let time = Double(i) * dt
            samples[i] = Float(generator(i, time, sampleRate))
        }
        
        return buffer
    }
}
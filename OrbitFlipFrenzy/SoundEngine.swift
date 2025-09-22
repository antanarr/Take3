import Foundation
import AVFoundation

public enum SoundEvent {
    case gameStart
    case playerFlip
    case nearMiss
    case collision
    case milestone
    case powerupCollect
}

public protocol SoundPlaying {
    func play(_ event: SoundEvent)
}

public final class SoundEngine: SoundPlaying {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let mixer = AVAudioMixerNode()
    private let queue = DispatchQueue(label: "SoundEngineQueue")

    public init() {
        engine.attach(player)
        engine.attach(mixer)
        engine.connect(player, to: mixer, format: nil)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        mixer.volume = 0.7
        try? engine.start()
    }

    public func play(_ event: SoundEvent) {
        queue.async { [weak self] in
            guard let self else { return }
            let (frequencies, durations) = self.configuration(for: event)
            let buffer = self.generateBuffer(frequencies: frequencies, durations: durations)
            self.player.stop()
            self.player.scheduleBuffer(buffer, at: nil, options: [])
            if !self.player.isPlaying {
                self.player.play()
            }
        }
    }

    private func configuration(for event: SoundEvent) -> ([Double], [Double]) {
        switch event {
        case .gameStart:
            return (stride(from: 130.81, through: 392.0, by: 30.0).map { $0 }, Array(repeating: 0.05, count: 9))
        case .playerFlip:
            return ([440.0], [0.1])
        case .nearMiss:
            return ([2000.0, 2100.0, 2200.0], [0.05, 0.05, 0.05])
        case .collision:
            return ([80.0, 60.0], [0.1, 0.1])
        case .milestone:
            return ([261.63, 329.63, 392.0, 523.25], [0.1, 0.1, 0.1, 0.1])
        case .powerupCollect:
            return ([261.63, 329.63, 392.0], [0.1, 0.1, 0.1])
        }
    }

    private func generateBuffer(frequencies: [Double], durations: [Double]) -> AVAudioPCMBuffer {
        let sampleRate = 44_100.0
        let totalDuration = zip(frequencies, durations).reduce(0.0) { partial, pair in
            let (_, duration) = pair
            return partial + duration
        }
        let totalFrames = max(AVAudioFrameCount(1), AVAudioFrameCount(totalDuration * sampleRate))
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames)!
        buffer.frameLength = totalFrames
        var frameIndex: AVAudioFrameCount = 0
        for (frequency, duration) in zip(frequencies, durations) {
            let frames = AVAudioFrameCount(duration * sampleRate)
            let envelopeFrames = max(AVAudioFrameCount(1), frames)
            for i in 0..<frames {
                let phase = Double(i) / sampleRate * frequency * 2.0 * Double.pi
                let value = sin(phase)
                let envelope = self.envelope(for: Int(i), total: Int(envelopeFrames))
                buffer.floatChannelData?.pointee[Int(frameIndex + i)] = Float(value * envelope)
            }
            frameIndex += frames
        }
        return buffer
    }

    private func envelope(for index: Int, total: Int) -> Double {
        guard total > 0 else { return 1.0 }
        let attack = Int(Double(total) * 0.1)
        let release = Int(Double(total) * 0.2)
        if index < attack {
            return Double(index) / Double(max(attack, 1))
        }
        if index > total - release {
            return max(Double(total - index) / Double(max(release, 1)), 0.0)
        }
        return 1.0
    }
}

//
//  AudioStaticManager.swift
//  urbanghosthunters
//

import AVFoundation

@MainActor
final class AudioStaticManager {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let mixerNode = AVAudioMixerNode()
    private var isRunning = false

    func prepare() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        engine.attach(playerNode)
        engine.attach(mixerNode)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(playerNode, to: mixerNode, format: format)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: format)

        mixerNode.outputVolume = 0

        scheduleNoise(format: format)

        do {
            try engine.start()
            playerNode.play()
            isRunning = true
        } catch {
            print("Audio engine error: \(error)")
        }
    }

    func setProximity(_ level: Double) {
        guard isRunning else { return }
        // Scale volume: silent at 0, max 0.6 at full proximity
        let volume = Float(min(level * 0.6, 0.6))
        mixerNode.outputVolume = volume
    }

    func stop() {
        playerNode.stop()
        engine.stop()
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func scheduleNoise(format: AVAudioFormat) {
        let bufferSize = AVAudioFrameCount(44100) // 1 second of noise
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize) else { return }
        buffer.frameLength = bufferSize

        // Fill buffer with white noise
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<Int(bufferSize) {
                channelData[i] = Float.random(in: -0.3...0.3)
            }
        }

        // Loop continuously
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
    }
}

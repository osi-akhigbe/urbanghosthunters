import AVFoundation
import Foundation

/// Hold-to-lure: mic amplitude (or simulated level) increases ghost reveal chance.
@Observable
@MainActor
final class MicLureManager {
    var revealLevel: Double = 0
    var amplitudeLevel: Double = 0
    var isHolding = false
    var micAvailable = false

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var simulateTimer: Timer?

    func prepare() {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            startMeteringRecorder()
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    if granted { self?.startMeteringRecorder() }
                }
            }
        default:
            micAvailable = false
        }
    }

    func beginLure() {
        isHolding = true
        if recorder?.isRecording == true {
            startMeterTimer()
        } else {
            startSimulatedLure()
        }
    }

    func endLure() {
        isHolding = false
        meterTimer?.invalidate()
        meterTimer = nil
        simulateTimer?.invalidate()
        simulateTimer = nil
        recorder?.stop()
    }

    func stop() {
        endLure()
        recorder = nil
    }

    private func startMeteringRecorder() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lure-meter.caf")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]

        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else {
            micAvailable = false
            return
        }
        rec.isMeteringEnabled = true
        recorder = rec
        micAvailable = rec.record()
    }

    private func startMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let rec = self.recorder, rec.isRecording else { return }
                rec.updateMeters()
                let power = rec.averagePower(forChannel: 0)
                let normalized = max(0, min(1, Double(power + 50) / 50))
                self.amplitudeLevel = normalized
                self.tickReveal(boost: normalized)
            }
        }
    }

    private func startSimulatedLure() {
        simulateTimer?.invalidate()
        simulateTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isHolding else { return }
                self.amplitudeLevel = min(1, self.amplitudeLevel + 0.08)
                self.tickReveal(boost: self.amplitudeLevel * 0.5)
            }
        }
    }

    private func tickReveal(boost: Double) {
        let gain = 0.02 + boost * 0.06
        revealLevel = min(1, revealLevel + gain)
        if revealLevel > 0.95 {
            revealLevel = 1
        }
    }
}

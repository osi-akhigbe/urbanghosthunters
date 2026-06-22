import AVFoundation
import SwiftUI

@Observable
@MainActor
final class FlashlightManager {
    static let shared = FlashlightManager()

    private(set) var isOn: Bool = false

    var hasTorch: Bool {
        AVCaptureDevice.default(for: .video)?.hasTorch ?? false
    }

    private var device: AVCaptureDevice? {
        AVCaptureDevice.default(for: .video)
    }

    private init() {}

    func toggle() {
        isOn ? turnOff() : turnOn()
    }

    func turnOn() {
        guard let device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            device.unlockForConfiguration()
            isOn = true
        } catch {
            isOn = false
        }
    }

    func turnOff() {
        guard let device, device.hasTorch, device.isTorchActive else {
            isOn = false
            return
        }
        do {
            try device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        } catch {}
        isOn = false
    }
}

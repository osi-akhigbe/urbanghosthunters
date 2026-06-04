import CoreMotion
import SwiftUI

/// Accelerometer shake detection + timed QTE prompts that drain shield.
@Observable
@MainActor
final class DisturbanceManager {
    var shieldLevel: Int = 100
    var shieldMax: Int = 100
    var activeQTE: Bool = false
    var qteLabel: String = "TAP!"
    var lastShakeMessage: String?

    private let motion = CMMotionManager()
    private var attackTimer: Timer?
    private var qteDeadline: Date?
    private var onShieldZero: (() -> Void)?

    private let config: HotspotDifficultyConfig
    private let equippedShieldBonus: Int

    init(config: HotspotDifficultyConfig, equippedShieldBonus: Int = 0) {
        self.config = config
        self.equippedShieldBonus = equippedShieldBonus
        shieldMax = config.shieldMax + equippedShieldBonus
        shieldLevel = shieldMax
    }

    func start(onShieldZero: @escaping () -> Void) {
        self.onShieldZero = onShieldZero
        startAccelerometer()
        scheduleAttacks()
    }

    func stop() {
        attackTimer?.invalidate()
        attackTimer = nil
        motion.stopAccelerometerUpdates()
        activeQTE = false
    }

    func handleQTETap() {
        guard activeQTE else { return }
        activeQTE = false
        qteDeadline = nil
        lastShakeMessage = "Blocked!"
    }

    func registerShake() {
        guard !activeQTE else { return }
        drainShield(config.attackShieldDamage / 2)
        lastShakeMessage = "Disturbance! Shield hit"
    }

    private func startAccelerometer() {
        guard motion.isAccelerometerAvailable else { return }
        motion.accelerometerUpdateInterval = 0.15
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let a = data.acceleration
            let magnitude = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            if magnitude > 2.2 {
                Task { @MainActor in self.registerShake() }
            }
        }
    }

    private func scheduleAttacks() {
        attackTimer?.invalidate()
        attackTimer = Timer.scheduledTimer(withTimeInterval: config.attackIntervalSeconds, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.triggerQTE() }
        }
    }

    private func triggerQTE() {
        guard !activeQTE else { return }
        activeQTE = true
        qteLabel = ["TAP!", "BLOCK!", "SEAL IT!"].randomElement() ?? "TAP!"
        qteDeadline = Date().addingTimeInterval(2)
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                guard self.activeQTE, let deadline = self.qteDeadline, Date() >= deadline else { return }
                self.activeQTE = false
                self.drainShield(self.config.attackShieldDamage)
                self.lastShakeMessage = "Missed QTE!"
            }
        }
    }

    private func drainShield(_ amount: Int) {
        shieldLevel = max(0, shieldLevel - amount)
        if shieldLevel == 0 {
            onShieldZero?()
        }
    }
}

struct ShieldMeterView: View {
    let level: Int
    let maxValue: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SHIELD")
                .font(.caption2).bold()
                .foregroundStyle(.white.opacity(0.6))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(level > 30 ? Color.cyan : Color.red)
                        .frame(width: geo.size.width * CGFloat(level) / CGFloat(Swift.max(1, maxValue)))
                }
            }
            .frame(height: 10)
            Text("\(level)/\(maxValue)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

struct QTEOverlay: View {
    let label: String
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(label)
                .font(.largeTitle).bold()
                .foregroundStyle(.yellow)
            Text("Tap now!")
                .font(.caption)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.red.opacity(0.35))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

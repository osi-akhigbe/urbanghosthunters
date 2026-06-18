import SwiftUI
import CoreHaptics
import Supabase
import ARKit

struct SealPoint: Equatable {
    let x: CGFloat
    let y: CGFloat
}

enum ContainmentOutcome {
    case success, failed, inProgress
}

@Observable
@MainActor
final class ContainmentViewModel {
    var points: [SealPoint] = []
    var outcome: ContainmentOutcome = .inProgress
    var reward: ContainmentReward?
    var showResult: Bool = false

    private var timer: Timer?
    private var hapticEngine: CHHapticEngine?
    let hotspot: Hotspot

    var timeRemaining: Int

    init(hotspot: Hotspot) {
        self.hotspot = hotspot
        self.timeRemaining = 10 + InventoryViewModel.shared.effects.sealTimeBonus
        prepareHaptics()
    }

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                } else {
                    self.evaluateSeal()
                }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func addPoint(_ point: SealPoint) {
        points.append(point)
    }

    // Default nil = timer expiry with no ghost position → auto fail
    func evaluateSeal(ghostScreenPosition: CGPoint? = nil) {
        stopTimer()
        guard points.count > 20 else {
            outcome = .failed
            reward = RewardCalculator.calculate(difficulty: hotspot.difficulty, success: false)
            showResult = true
            return
        }

        guard let first = points.first, let last = points.last else {
            outcome = .failed
            reward = RewardCalculator.calculate(difficulty: hotspot.difficulty, success: false)
            showResult = true
            return
        }

        let dx = first.x - last.x
        let dy = first.y - last.y
        let closed = sqrt(dx * dx + dy * dy) < 60

        let ghostCaptured: Bool
        if let ghostPos = ghostScreenPosition {
            ghostCaptured = sealContains(ghostPos)
        } else {
            ghostCaptured = false
        }

        let success = closed && ghostCaptured
        outcome = success ? .success : .failed
        reward = RewardCalculator.calculate(difficulty: hotspot.difficulty, success: success)
        showResult = true
        playResultHaptic()

        Task { await saveEncounter() }
    }

    private func sealContains(_ point: CGPoint) -> Bool {
        guard points.count > 5 else { return false }
        var path = Path()
        path.move(to: CGPoint(x: points[0].x, y: points[0].y))
        for p in points.dropFirst() {
            path.addLine(to: CGPoint(x: p.x, y: p.y))
        }
        path.closeSubpath()
        return path.contains(point)
    }

    func saveEncounter() async {
        guard let userId = SupabaseManager.shared.userId,
              let reward else { return }

        struct RewardsJSON: Encodable {
            let xp: Int
            let totem_shards: Int
            let totem_granted: String?
        }

        struct EncounterInsert: Encodable {
            let user_id: String
            let hotspot_id: UUID
            let outcome: String
            let rewards_json: RewardsJSON
        }

        let insert = EncounterInsert(
            user_id: userId,
            hotspot_id: hotspot.id,
            outcome: outcome == .success ? "captured" : "failed",
            rewards_json: RewardsJSON(
                xp: reward.xp,
                totem_shards: reward.totemShards,
                totem_granted: reward.newTotem?.rawValue
            )
        )

        do {
            try await SupabaseManager.shared.client
                .from("encounters")
                .insert(insert)
                .execute()
        } catch {
            print("Failed to save encounter: \(error)")
        }

        if let newTotemType = reward.newTotem {
            await grantTotem(type: newTotemType, userId: userId)
        }
    }

    private func grantTotem(type: TotemType, userId: String) async {
        struct TotemInsert: Encodable {
            let user_id: String
            let type: String
            let equipped: Bool
            let effect_json: String
        }
        let row = TotemInsert(
            user_id: userId,
            type: type.rawValue,
            equipped: false,
            effect_json: "{}"
        )
        do {
            try await SupabaseManager.shared.client
                .from("totems")
                .insert(row)
                .execute()
            await InventoryViewModel.shared.fetch()
        } catch {
            print("Failed to grant totem: \(error)")
        }
    }

    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        try? hapticEngine?.start()
    }

    func playResultHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        let event = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [intensity, sharpness], relativeTime: 0)

        if let pattern = try? CHHapticPattern(events: [event], parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: 0)
        }
    }
}

// MARK: - AR Container

struct ARContainerView: View {
    var proximityLevel: Double
    var onTrackingMessage: ((String?) -> Void)?
    var onGhostScreenPosition: ((CGPoint) -> Void)?

    var body: some View {
        ARGhostView(
            proximityLevel: proximityLevel,
            onTrackingMessage: onTrackingMessage,
            onGhostScreenPosition: onGhostScreenPosition
        )
        .ignoresSafeArea()
    }
}

// MARK: - Containment View

struct ContainmentView: View {
    let hotspot: Hotspot
    let proximityLevel: Double
    @State private var vm: ContainmentViewModel
    @State private var arTrackingMessage: String? = "Initializing AR…"
    @State private var ghostScreenPosition: CGPoint?
    @Environment(\.dismiss) private var dismiss

    private let arSupported = ARWorldTrackingConfiguration.isSupported

    init(hotspot: Hotspot, proximityLevel: Double) {
        self.hotspot = hotspot
        self.proximityLevel = proximityLevel
        _vm = State(initialValue: ContainmentViewModel(hotspot: hotspot))
    }

    var body: some View {
        ZStack {
            if arSupported {
                ARContainerView(
                    proximityLevel: proximityLevel,
                    onTrackingMessage: { arTrackingMessage = $0 },
                    onGhostScreenPosition: { ghostScreenPosition = $0 }
                )
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                GridPattern()
                    .stroke(Color.purple.opacity(0.15), lineWidth: 1)
                    .ignoresSafeArea()
            }

            Color.black.opacity(0.45)
                .ignoresSafeArea()

            GridPattern()
                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                .ignoresSafeArea()

            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("CONTAINMENT")
                            .font(.caption).bold()
                            .foregroundStyle(.purple)
                        Text(hotspot.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(vm.timeRemaining)s")
                            .font(.title).bold()
                            .foregroundStyle(vm.timeRemaining <= 3 ? .red : .green)
                            .monospacedDigit()

                        let bonus = InventoryViewModel.shared.effects.sealTimeBonus
                        if bonus > 0 {
                            Text("+\(bonus)s from totem")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                        }
                    }
                }
                .padding()

                SealCanvas(points: vm.points, ghostPosition: ghostScreenPosition) { point in
                    vm.addPoint(point)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    Text(ghostScreenPosition != nil ? "Draw a seal AROUND the ghost" : "Waiting for ghost…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 8),
                    alignment: .bottom
                )

                Button {
                    vm.evaluateSeal(ghostScreenPosition: ghostScreenPosition)
                } label: {
                    Text("SEAL")
                        .font(.headline).bold()
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
        }
        .overlay(alignment: .top) {
            if arSupported, let message = arTrackingMessage {
                Text(message)
                    .font(.caption).bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.top, 60)
            }
        }
        .onAppear { vm.startTimer() }
        .onDisappear { vm.stopTimer() }
        .sheet(isPresented: $vm.showResult) {
            if let reward = vm.reward {
                ResultSheet(outcome: vm.outcome, hotspot: hotspot, reward: reward) {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Result Sheet

struct ResultSheet: View {
    let outcome: ContainmentOutcome
    let hotspot: Hotspot
    let reward: ContainmentReward
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: outcome == .success ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(outcome == .success ? .green : .red)

            Text(outcome == .success ? "Ghost Contained!" : "Containment Failed")
                .font(.title2).bold()
                .foregroundStyle(outcome == .success ? .green : .red)

            Text(hotspot.name)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                RewardRow(icon: "star.fill", label: "XP Earned", value: "+\(reward.xp) XP", color: .yellow)

                if reward.totemShards > 0 {
                    RewardRow(icon: "seal.fill",
                              label: "Totem Shards",
                              value: "+\(reward.totemShards)",
                              color: .cyan)
                }

                if let newTotem = reward.newTotem {
                    RewardRow(icon: newTotem.icon,
                              label: "Totem Unlocked",
                              value: newTotem.displayName,
                              color: .purple)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            Button("Continue") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding()
        .presentationDetents([.medium])
    }
}

private struct RewardRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .bold()
                .foregroundStyle(color)
        }
        .font(.subheadline)
    }
}

// MARK: - Seal Canvas

struct SealCanvas: View {
    let points: [SealPoint]
    let ghostPosition: CGPoint?
    let onPoint: (SealPoint) -> Void

    var body: some View {
        Canvas { context, _ in
            // Draw ghost target crosshair
            if let ghost = ghostPosition {
                let radius: CGFloat = 24
                let crossLen: CGFloat = 10
                // Pulsing ring around ghost
                let ring = Path(ellipseIn: CGRect(
                    x: ghost.x - radius, y: ghost.y - radius,
                    width: radius * 2, height: radius * 2
                ))
                context.stroke(ring, with: .color(.purple.opacity(0.7)), lineWidth: 2)
                // Small crosshair
                var cross = Path()
                cross.move(to: CGPoint(x: ghost.x - crossLen, y: ghost.y))
                cross.addLine(to: CGPoint(x: ghost.x + crossLen, y: ghost.y))
                cross.move(to: CGPoint(x: ghost.x, y: ghost.y - crossLen))
                cross.addLine(to: CGPoint(x: ghost.x, y: ghost.y + crossLen))
                context.stroke(cross, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
            }

            // Draw the player's seal stroke
            guard points.count > 1 else { return }
            var path = Path()
            path.move(to: CGPoint(x: points[0].x, y: points[0].y))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            context.stroke(path, with: .color(.purple), lineWidth: 3)
            context.stroke(path, with: .color(.purple.opacity(0.3)), lineWidth: 8)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onPoint(SealPoint(x: value.location.x, y: value.location.y))
                }
        )
        .background(Color.clear)
    }
}

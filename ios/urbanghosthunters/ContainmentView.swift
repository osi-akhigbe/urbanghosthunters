import SwiftUI
import CoreHaptics
import Supabase

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
        }
        let row = TotemInsert(
            user_id: userId,
            type: type.rawValue,
            equipped: false
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

// MARK: - AR Container (camera + 3D ghost)

struct ARContainerView: View {
    var onTrackingMessage: ((String?) -> Void)?
    var onGhostScreenPosition: ((CGPoint) -> Void)?

    var body: some View {
        ARGhostView(
            proximityLevel: 1.0,
            showGhost: true,
            skin: GhostSkinManager.shared.activeSkin,
            onTrackingMessage: onTrackingMessage,
            onGhostScreenPosition: onGhostScreenPosition
        )
        .ignoresSafeArea()
    }
}

// MARK: - Containment View

struct ContainmentView: View {
    let hotspot: Hotspot
    @State private var vm: ContainmentViewModel
    @State private var arTrackingMessage: String? = "Initializing AR…"
    @State private var ghostScreenPosition: CGPoint?
    @Environment(\.dismiss) private var dismiss

    private var timerColor: Color {
        vm.timeRemaining <= 3 ? Kit.Colors.danger : Kit.Colors.signal
    }

    init(hotspot: Hotspot) {
        self.hotspot = hotspot
        _vm = State(initialValue: ContainmentViewModel(hotspot: hotspot))
    }

    var body: some View {
        ZStack {
            // Single ARView: real camera feed + 3D ghost model anchored to camera
            ARContainerView(
                onTrackingMessage: { arTrackingMessage = $0 },
                onGhostScreenPosition: { ghostScreenPosition = $0 }
            )

            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                KitHUDHeader(
                    module: "CONTAINMENT",
                    title: hotspot.name,
                    subtitle: timerSubtitle,
                    readout: .init(
                        label: "SEAL TIMER",
                        value: "\(vm.timeRemaining)s",
                        valueColor: timerColor
                    )
                )

                SealCanvas(points: vm.points, ghostPosition: ghostScreenPosition) { point in
                    vm.addPoint(point)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .overlay(alignment: .bottom) {
                    Text(ghostScreenPosition != nil ? "DRAW A SEAL AROUND THE GHOST" : "WAITING FOR GHOST…")
                        .font(Kit.Font.label())
                        .foregroundStyle(Kit.Colors.muted)
                        .tracking(Kit.Layout.labelTracking)
                        .padding(.bottom, 12)
                }

                KitPrimaryButton(title: "SEAL") {
                    vm.evaluateSeal(ghostScreenPosition: ghostScreenPosition)
                }
                .padding(16)
            }
        }
        .overlay(alignment: .top) {
            if let message = arTrackingMessage {
                Text(message)
                    .font(Kit.Font.label())
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

    private var timerSubtitle: String? {
        let bonus = InventoryViewModel.shared.effects.sealTimeBonus
        guard bonus > 0 else { return nil }
        return "+\(bonus)S TOTEM BONUS"
    }
}

// MARK: - Seal Canvas

struct SealCanvas: View {
    let points: [SealPoint]
    let ghostPosition: CGPoint?
    let onPoint: (SealPoint) -> Void

    var body: some View {
        Canvas { context, _ in
            if let ghost = ghostPosition {
                let radius: CGFloat = 24
                let crossLen: CGFloat = 10
                let ring = Path(ellipseIn: CGRect(
                    x: ghost.x - radius, y: ghost.y - radius,
                    width: radius * 2, height: radius * 2
                ))
                context.stroke(ring, with: .color(Kit.Colors.accent.opacity(0.7)), lineWidth: 2)
                var cross = Path()
                cross.move(to: CGPoint(x: ghost.x - crossLen, y: ghost.y))
                cross.addLine(to: CGPoint(x: ghost.x + crossLen, y: ghost.y))
                cross.move(to: CGPoint(x: ghost.x, y: ghost.y - crossLen))
                cross.addLine(to: CGPoint(x: ghost.x, y: ghost.y + crossLen))
                context.stroke(cross, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
            }

            guard points.count > 1 else { return }
            var path = Path()
            path.move(to: CGPoint(x: points[0].x, y: points[0].y))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            context.stroke(path, with: .color(Kit.Colors.accent.opacity(0.35)), lineWidth: 10)
            context.stroke(path, with: .color(Kit.Colors.accent), lineWidth: 3)
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
                .foregroundStyle(outcome == .success ? Kit.Colors.signal : Kit.Colors.danger)

            Text(outcome == .success ? "Ghost Contained!" : "Containment Failed")
                .font(Kit.Font.readout(22))
                .foregroundStyle(outcome == .success ? Kit.Colors.signal : Kit.Colors.danger)

            Text(hotspot.name)
                .font(Kit.Font.body())
                .foregroundStyle(Kit.Colors.label)

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
                              color: Kit.Colors.accent)
                }
            }
            .padding()
            .background(Kit.Colors.panel, in: RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius))
            .padding(.horizontal)

            KitPrimaryButton(title: "CONTINUE", action: onDismiss)
                .padding(.horizontal)
        }
        .padding()
        .presentationDetents([.medium])
        .presentationBackground(Kit.Colors.background)
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

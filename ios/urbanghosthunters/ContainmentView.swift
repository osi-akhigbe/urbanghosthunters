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

    func evaluateSeal() {
        stopTimer()
        guard points.count > 20 else {
            outcome = .failed
            showResult = true
            return
        }

        guard let first = points.first, let last = points.last else {
            outcome = .failed
            showResult = true
            return
        }

        let dx = first.x - last.x
        let dy = first.y - last.y
        let distance = sqrt(dx * dx + dy * dy)

        outcome = distance < 60 ? .success : .failed
        showResult = true
        playResultHaptic()

        Task { await saveEncounter() }
    }

    func saveEncounter() async {
        guard let userId = SupabaseManager.shared.userId else { return }

        struct EncounterInsert: Encodable {
            let user_id: String
            let hotspot_id: UUID
            let outcome: String
            let rewards_json: RewardsJSON
        }

        struct RewardsJSON: Encodable {
            let xp: Int
        }

        let xp = outcome == .success ? 100 : 10
        let insert = EncounterInsert(
            user_id: userId,
            hotspot_id: hotspot.id,
            outcome: outcome == .success ? "captured" : "failed",
            rewards_json: RewardsJSON(xp: xp)
        )

        do {
            try await SupabaseManager.shared.client
                .from("encounters")
                .insert(insert)
                .execute()
        } catch {
            print("Failed to save encounter: \(error)")
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

struct ContainmentView: View {
    let hotspot: Hotspot
    @State private var vm: ContainmentViewModel
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
            KitScreenBackground()

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

                SealCanvas(points: vm.points) { point in
                    vm.addPoint(point)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .overlay(alignment: .bottom) {
                    Text("DRAW A SEAL TO CONTAIN THE GHOST")
                        .font(Kit.Font.label())
                        .foregroundStyle(Kit.Colors.muted)
                        .tracking(Kit.Layout.labelTracking)
                        .padding(.bottom, 12)
                }

                KitPrimaryButton(title: "SEAL") {
                    vm.evaluateSeal()
                }
                .padding(16)
            }
        }
        .kitScreen()
        .onAppear { vm.startTimer() }
        .onDisappear { vm.stopTimer() }
        .sheet(isPresented: $vm.showResult) {
            KitOutcomeSheet(
                success: vm.outcome == .success,
                title: vm.outcome == .success ? "GHOST CONTAINED" : "CONTAINMENT FAILED",
                subtitle: hotspot.name,
                reward: vm.outcome == .success ? "+100 XP" : "+10 XP",
                buttonTitle: "CONTINUE"
            ) {
                dismiss()
            }
        }
    }

    private var timerSubtitle: String? {
        let bonus = InventoryViewModel.shared.effects.sealTimeBonus
        guard bonus > 0 else { return nil }
        return "+\(bonus)S TOTEM BONUS"
    }
}

struct SealCanvas: View {
    let points: [SealPoint]
    let onPoint: (SealPoint) -> Void

    var body: some View {
        Canvas { context, _ in
            guard points.count > 1 else { return }
            var path = Path()
            path.move(to: CGPoint(x: points[0].x, y: points[0].y))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            context.stroke(path, with: .color(Kit.Colors.accent.opacity(0.35)), lineWidth: 10)
            context.stroke(path, with: .color(Kit.Colors.accent), lineWidth: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Kit.Colors.panel, in: RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
                .stroke(Kit.Colors.panelBorder, lineWidth: 1)
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onPoint(SealPoint(x: value.location.x, y: value.location.y))
                }
        )
    }
}

struct ResultSheet: View {
    let outcome: ContainmentOutcome
    let hotspot: Hotspot
    let onDismiss: () -> Void

    var body: some View {
        KitOutcomeSheet(
            success: outcome == .success,
            title: outcome == .success ? "GHOST CONTAINED" : "CONTAINMENT FAILED",
            subtitle: hotspot.name,
            reward: outcome == .success ? "+100 XP" : "+10 XP",
            buttonTitle: "CONTINUE",
            onDismiss: onDismiss
        )
    }
}

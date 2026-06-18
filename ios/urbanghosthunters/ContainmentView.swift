<<<<<<< HEAD
<<<<<<< HEAD
=======
//
//  ContainmentView.swift
//  urbanghosthunters
//

>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
import SwiftUI
import CoreHaptics
import Supabase

<<<<<<< HEAD
<<<<<<< HEAD
=======
// MARK: - Seal drawing model
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
struct SealPoint: Equatable {
    let x: CGFloat
    let y: CGFloat
}

<<<<<<< HEAD
<<<<<<< HEAD
=======
// MARK: - Encounter result
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
enum ContainmentOutcome {
    case success, failed, inProgress
}

<<<<<<< HEAD
<<<<<<< HEAD
=======
// MARK: - ViewModel
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
@Observable
@MainActor
final class ContainmentViewModel {
    var points: [SealPoint] = []
    var outcome: ContainmentOutcome = .inProgress
<<<<<<< HEAD
<<<<<<< HEAD
=======
    var timeRemaining: Int = 10
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
    var reward: ContainmentReward?
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    var showResult: Bool = false

    private var timer: Timer?
    private var hapticEngine: CHHapticEngine?
    let hotspot: Hotspot

<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    var timeRemaining: Int

    init(hotspot: Hotspot) {
        self.hotspot = hotspot
<<<<<<< HEAD
        self.timeRemaining = 10 + PlayerInventory.shared.shieldBonus
        prepareHaptics()
    }

=======
    init(hotspot: Hotspot) {
        self.hotspot = hotspot
        prepareHaptics()
    }

    // MARK: - Timer
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
        self.timeRemaining = 10 + InventoryViewModel.shared.effects.sealTimeBonus
        prepareHaptics()
    }

    // Counts down every second and auto-evaluates when time runs out
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
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

<<<<<<< HEAD
=======
    // Cancels the countdown timer
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

<<<<<<< HEAD
<<<<<<< HEAD
=======
    // MARK: - Seal evaluation
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
    // Appends a new point to the seal drawing path
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    func addPoint(_ point: SealPoint) {
        points.append(point)
    }

<<<<<<< HEAD
=======
    // Checks whether the drawn seal is valid (enough points and roughly closed),
    // then calculates the reward and kicks off the save
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    func evaluateSeal() {
        stopTimer()
        guard points.count > 20 else {
            outcome = .failed
<<<<<<< HEAD
=======
            reward = RewardCalculator.calculate(difficulty: hotspot.difficulty, success: false)
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
            showResult = true
            return
        }

<<<<<<< HEAD
<<<<<<< HEAD
=======
        // Check if seal is roughly closed (start and end points within 60pts)
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
        guard let first = points.first, let last = points.last else {
            outcome = .failed
=======
        guard let first = points.first, let last = points.last else {
            outcome = .failed
            reward = RewardCalculator.calculate(difficulty: hotspot.difficulty, success: false)
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
            showResult = true
            return
        }

        let dx = first.x - last.x
        let dy = first.y - last.y
<<<<<<< HEAD
        let distance = sqrt(dx * dx + dy * dy)

        outcome = distance < 60 ? .success : .failed
=======
        let closed = sqrt(dx * dx + dy * dy) < 60

        outcome = closed ? .success : .failed
        reward = RewardCalculator.calculate(difficulty: hotspot.difficulty, success: closed)
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
        showResult = true
        playResultHaptic()

        Task { await saveEncounter() }
    }

<<<<<<< HEAD
<<<<<<< HEAD
=======
    // MARK: - Save to Supabase
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
    func saveEncounter() async {
        guard let userId = SupabaseManager.shared.userId else { return }
=======
    // Saves the encounter result and reward to Supabase.
    // If a new totem was earned, inserts it into the totems table and refreshes inventory.
    func saveEncounter() async {
        guard let userId = SupabaseManager.shared.userId,
              let reward else { return }

        struct RewardsJSON: Encodable {
            let xp: Int
            let totem_shards: Int
            let totem_granted: String?
        }
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem

        struct EncounterInsert: Encodable {
            let user_id: String
            let hotspot_id: UUID
            let outcome: String
            let rewards_json: RewardsJSON
        }

<<<<<<< HEAD
        struct RewardsJSON: Encodable {
            let xp: Int
        }

        let xp = outcome == .success ? 100 : 10
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
        let insert = EncounterInsert(
            user_id: userId,
            hotspot_id: hotspot.id,
            outcome: outcome == .success ? "captured" : "failed",
<<<<<<< HEAD
            rewards_json: RewardsJSON(xp: xp)
=======
            rewards_json: RewardsJSON(
                xp: reward.xp,
                totem_shards: reward.totemShards,
                totem_granted: reward.newTotem?.rawValue
            )
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
        )

        do {
            try await SupabaseManager.shared.client
                .from("encounters")
                .insert(insert)
                .execute()
        } catch {
            print("Failed to save encounter: \(error)")
        }
<<<<<<< HEAD
    }

<<<<<<< HEAD
=======
    // MARK: - Haptics
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======

        // Grant the new totem if one was earned
        if let newTotemType = reward.newTotem {
            await grantTotem(type: newTotemType, userId: userId)
        }
    }

    // Inserts a new totem row and refreshes the inventory so it appears immediately
    private func grantTotem(type: TotemType, userId: String) async {
        let row: [String: any Sendable] = [
            "user_id":     userId,
            "type":        type.rawValue,
            "equipped":    false,
            "effect_json": "{}"
        ]
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

    // Prepares the haptic engine on supported devices
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        try? hapticEngine?.start()
    }

<<<<<<< HEAD
=======
    // Plays a strong single haptic when the result is determined
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    func playResultHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
<<<<<<< HEAD
<<<<<<< HEAD
        let event = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [intensity, sharpness], relativeTime: 0)
=======
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
        let event = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [intensity, sharpness], relativeTime: 0)
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem

        if let pattern = try? CHHapticPattern(events: [event], parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: 0)
        }
    }
}

<<<<<<< HEAD
<<<<<<< HEAD
=======
// MARK: - Main View
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
// MARK: - Containment View

>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
struct ContainmentView: View {
    let hotspot: Hotspot
    @State private var vm: ContainmentViewModel
    @Environment(\.dismiss) private var dismiss

    init(hotspot: Hotspot) {
        self.hotspot = hotspot
        _vm = State(initialValue: ContainmentViewModel(hotspot: hotspot))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

<<<<<<< HEAD
<<<<<<< HEAD
=======
            // HUD background grid
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
            GridPattern()
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
                .ignoresSafeArea()

            VStack {
<<<<<<< HEAD
<<<<<<< HEAD
=======
                // Top HUD
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
                // Top HUD: location label and countdown
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
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
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(vm.timeRemaining)s")
                            .font(.title).bold()
                            .foregroundStyle(vm.timeRemaining <= 3 ? .red : .green)
                            .monospacedDigit()

<<<<<<< HEAD
                        let bonus = PlayerInventory.shared.shieldBonus
=======
                        let bonus = InventoryViewModel.shared.effects.sealTimeBonus
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                        if bonus > 0 {
                            Text("+\(bonus)s from totem")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                        }
                    }
                }
                .padding()

<<<<<<< HEAD
=======
                    // Countdown
                    Text("\(vm.timeRemaining)s")
                        .font(.title).bold()
                        .foregroundStyle(vm.timeRemaining <= 3 ? .red : .green)
                        .monospacedDigit()
                }
                .padding()

                // Drawing canvas
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                SealCanvas(points: vm.points) { point in
                    vm.addPoint(point)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    Text("Draw a seal to contain the ghost")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 8),
                    alignment: .bottom
                )

<<<<<<< HEAD
<<<<<<< HEAD
=======
                // Submit button
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                Button {
                    vm.evaluateSeal()
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
        .onAppear { vm.startTimer() }
        .onDisappear { vm.stopTimer() }
        .sheet(isPresented: $vm.showResult) {
<<<<<<< HEAD
            ResultSheet(outcome: vm.outcome, hotspot: hotspot) {
                dismiss()
=======
            if let reward = vm.reward {
                ResultSheet(outcome: vm.outcome, hotspot: hotspot, reward: reward) {
                    dismiss()
                }
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
            }
        }
    }
}

<<<<<<< HEAD
<<<<<<< HEAD
=======
// MARK: - Seal Canvas
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
// MARK: - Result Sheet

struct ResultSheet: View {
    let outcome: ContainmentOutcome
    let hotspot: Hotspot
    let reward: ContainmentReward
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Outcome icon
            Image(systemName: outcome == .success ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(outcome == .success ? .green : .red)

            Text(outcome == .success ? "Ghost Contained!" : "Containment Failed")
                .font(.title2).bold()
                .foregroundStyle(outcome == .success ? .green : .red)

            Text(hotspot.name)
                .font(.headline)
                .foregroundStyle(.secondary)

            // Reward breakdown
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

// A single line in the reward breakdown
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

>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
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
            context.stroke(path, with: .color(.purple), lineWidth: 3)
<<<<<<< HEAD
<<<<<<< HEAD
=======

            // Glow effect
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
            context.stroke(path, with: .color(.purple.opacity(0.3)), lineWidth: 8)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onPoint(SealPoint(x: value.location.x, y: value.location.y))
                }
        )
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
        .background(Color.black.opacity(0.01))
    }
}

<<<<<<< HEAD
=======
        .background(Color.black.opacity(0.01)) // needed for gesture hit testing
    }
}

// MARK: - Grid Pattern
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
struct GridPattern: Shape {
=======
// MARK: - Grid Pattern

struct GridPattern: Shape {
    // Draws an evenly spaced grid of lines across the available rect
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 30
        var x: CGFloat = 0
        while x <= rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }
        var y: CGFloat = 0
        while y <= rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }
        return path
    }
}
<<<<<<< HEAD

<<<<<<< HEAD
=======
// MARK: - Result Sheet
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
struct ResultSheet: View {
    let outcome: ContainmentOutcome
    let hotspot: Hotspot
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

            Text(outcome == .success ? "+100 XP" : "+10 XP")
                .font(.title3).bold()
                .foregroundStyle(.purple)

            Button("Continue") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding()
        .presentationDetents([.medium])
    }
<<<<<<< HEAD
}
=======
}
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem

//
//  ContainmentView.swift
//  urbanghosthunters
//

import SwiftUI
import CoreHaptics
import Supabase

// MARK: - Seal drawing model
struct SealPoint: Equatable {
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Encounter result
enum ContainmentOutcome {
    case success, failed, inProgress
}

// MARK: - ViewModel
@Observable
@MainActor
final class ContainmentViewModel {
    var points: [SealPoint] = []
    var outcome: ContainmentOutcome = .inProgress
    var timeRemaining: Int = 10
    var showResult: Bool = false
    var saveMessage: String?
    var earnedTotemName: String?
    var shieldLevelForEvaluation: Int = 100

    private var timer: Timer?
    private var hapticEngine: CHHapticEngine?
    let hotspot: Hotspot
    let config: HotspotDifficultyConfig

    init(hotspot: Hotspot) {
        self.hotspot = hotspot
        self.config = HotspotDifficultyConfig.config(for: hotspot.difficulty)
        self.timeRemaining = config.timerSeconds
        prepareHaptics()
    }

    // MARK: - Timer
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                } else {
                    self.evaluateSeal(shieldLevel: self.shieldLevelForEvaluation)
                }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Seal evaluation
    func addPoint(_ point: SealPoint) {
        points.append(point)
    }

    func evaluateSeal(shieldLevel: Int) {
        stopTimer()
        guard shieldLevel > 0 else {
            outcome = .failed
            saveMessage = "Shield depleted!"
            showResult = true
            return
        }

        guard points.count > config.minSealPoints else {
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

        outcome = distance < config.sealCloseDistance ? .success : .failed
        showResult = true
        playResultHaptic()

        Task { await saveEncounter() }
    }

    // MARK: - Save to Supabase
    func saveEncounter() async {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else {
            saveMessage = "Not signed in — result not saved."
            return
        }

        struct EncounterInsert: Encodable {
            let user_id: UUID
            let hotspot_id: UUID
            let outcome: String
            let rewards_json: RewardsJSON
        }

        struct RewardsJSON: Encodable {
            let xp: Int
            let totem_name: String?
        }

        let xp = outcome == .success ? (100 * hotspot.difficulty) : 10
        var totemName: String?
        if outcome == .success {
            await PlayerInventory.shared.grantTotemIfNeeded(totemName: "Spirit Ward")
            totemName = "Spirit Ward"
            earnedTotemName = totemName
        }

        let insert = EncounterInsert(
            user_id: userId,
            hotspot_id: hotspot.id,
            outcome: outcome == .success ? "captured" : "failed",
            rewards_json: RewardsJSON(xp: xp, totem_name: totemName)
        )

        do {
            try await SupabaseManager.shared.client
                .from("encounters")
                .insert(insert)
                .execute()
            saveMessage = "Saved to Supabase ✓"
        } catch {
            saveMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Haptics
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
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)

        if let pattern = try? CHHapticPattern(events: [event], parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: 0)
        }
    }
}

// MARK: - Main View
struct ContainmentView: View {
    let hotspot: Hotspot
    @State private var vm: ContainmentViewModel
    @State private var disturbance: DisturbanceManager
    @Environment(\.dismiss) private var dismiss

    init(hotspot: Hotspot) {
        self.hotspot = hotspot
        let config = HotspotDifficultyConfig.config(for: hotspot.difficulty)
        _vm = State(initialValue: ContainmentViewModel(hotspot: hotspot))
        _disturbance = State(initialValue: DisturbanceManager(
            config: config,
            equippedShieldBonus: PlayerInventory.shared.shieldBonus
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GridPattern()
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
                .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text("CONTAINMENT")
                            .font(.caption).bold()
                            .foregroundStyle(.purple)
                        Text(hotspot.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Diff \(hotspot.difficulty) · \(vm.config.timerSeconds)s · seal \(vm.config.minSealPoints)+ pts")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("\(vm.timeRemaining)s")
                            .font(.title).bold()
                            .foregroundStyle(vm.timeRemaining <= 3 ? .red : .green)
                            .monospacedDigit()
                        ShieldMeterView(level: disturbance.shieldLevel, maxValue: disturbance.shieldMax)
                            .frame(width: 120)
                    }
                }
                .padding()

                if let msg = disturbance.lastShakeMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                SealCanvas(points: vm.points) { point in
                    vm.addPoint(point)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    Text("Draw a closed seal — shake phone triggers disturbances")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 8),
                    alignment: .bottom
                )

                Button {
                    vm.evaluateSeal(shieldLevel: disturbance.shieldLevel)
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
        .onChange(of: disturbance.shieldLevel) { _, level in
            vm.shieldLevelForEvaluation = level
        }
        .onAppear {
            vm.shieldLevelForEvaluation = disturbance.shieldLevel
            vm.startTimer()
            disturbance.start {
                vm.stopTimer()
                vm.outcome = .failed
                vm.saveMessage = "Shield broken!"
                vm.showResult = true
            }
        }
        .onDisappear {
            vm.stopTimer()
            disturbance.stop()
        }
        .overlay {
            if disturbance.activeQTE {
                QTEOverlay(label: disturbance.qteLabel) {
                    disturbance.handleQTETap()
                }
            }
        }
        .sheet(isPresented: $vm.showResult) {
            ResultSheet(
                outcome: vm.outcome,
                hotspot: hotspot,
                saveMessage: vm.saveMessage,
                totemName: vm.earnedTotemName
            ) {
                dismiss()
            }
        }
    }
}

// MARK: - Seal Canvas
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

            // Glow effect
            context.stroke(path, with: .color(.purple.opacity(0.3)), lineWidth: 8)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onPoint(SealPoint(x: value.location.x, y: value.location.y))
                }
        )
        .background(Color.black.opacity(0.01)) // needed for gesture hit testing
    }
}

// MARK: - Result Sheet
struct ResultSheet: View {
    let outcome: ContainmentOutcome
    let hotspot: Hotspot
    let saveMessage: String?
    var totemName: String?
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

            if let totemName, outcome == .success {
                Text("Earned totem: \(totemName)")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
            }

            if let saveMessage {
                Text(saveMessage)
                    .font(.footnote)
                    .foregroundStyle(saveMessage.contains("✓") ? .green : .orange)
                    .multilineTextAlignment(.center)
            }

            Text("Next: Journal → Loadout → equip totem → replay from detail")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

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

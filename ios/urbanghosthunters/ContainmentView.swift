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

    init(hotspot: Hotspot) {
        self.hotspot = hotspot
        _vm = State(initialValue: ContainmentViewModel(hotspot: hotspot))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GridPattern()
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
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
            ResultSheet(outcome: vm.outcome, hotspot: hotspot) {
                dismiss()
            }
        }
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
            context.stroke(path, with: .color(.purple), lineWidth: 3)
            context.stroke(path, with: .color(.purple.opacity(0.3)), lineWidth: 8)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onPoint(SealPoint(x: value.location.x, y: value.location.y))
                }
        )
        .background(Color.black.opacity(0.01))
    }
}

struct GridPattern: Shape {
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
}

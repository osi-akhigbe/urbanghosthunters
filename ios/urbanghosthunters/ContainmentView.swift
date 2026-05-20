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

    private var timer: Timer?
    private var hapticEngine: CHHapticEngine?
    let hotspot: Hotspot

    init(hotspot: Hotspot) {
        self.hotspot = hotspot
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
                    self.evaluateSeal()
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

    func evaluateSeal() {
        stopTimer()
        guard points.count > 20 else {
            outcome = .failed
            showResult = true
            return
        }

        // Check if seal is roughly closed (start and end points within 60pts)
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

    // MARK: - Save to Supabase
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
    @Environment(\.dismiss) private var dismiss

    init(hotspot: Hotspot) {
        self.hotspot = hotspot
        _vm = State(initialValue: ContainmentViewModel(hotspot: hotspot))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // HUD background grid
            GridPattern()
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
                .ignoresSafeArea()

            VStack {
                // Top HUD
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
                    // Countdown
                    Text("\(vm.timeRemaining)s")
                        .font(.title).bold()
                        .foregroundStyle(vm.timeRemaining <= 3 ? .red : .green)
                        .monospacedDigit()
                }
                .padding()

                // Drawing canvas
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

                // Submit button
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

// MARK: - Grid Pattern
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

// MARK: - Result Sheet
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

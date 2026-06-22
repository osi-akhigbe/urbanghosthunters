//
//  GhostPreviewView.swift
//  urbanghosthunters
//
//  Test scene — shows 5 randomised ghost variants in AR so you can
//  inspect the look before going into a real encounter.
//  Add a NavigationLink or sheet to this from any debug/settings screen.
//

import SwiftUI
import ARKit
import RealityKit

// MARK: - Preview Shell
struct GhostPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var personalities: [GhostPersonality] = Self.freshPersonalities()
    @State private var labelText = "5 ghosts · randomised shapes & expressions"

    var body: some View {
        ZStack {
            GhostPreviewARView(personalities: personalities)
                .ignoresSafeArea()

            // Thin dark vignette so UI is readable over the camera
            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.40)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.white)
                            .font(.subheadline.weight(.semibold))
                    }

                    Spacer()

                    Button {
                        personalities = Self.freshPersonalities()
                        labelText = "Regenerated · \(Date().formatted(date: .omitted, time: .shortened))"
                    } label: {
                        Label("Regenerate", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.yellow)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 52)

                Spacer()

                // Legend
                VStack(spacing: 4) {
                    Text("GHOST PREVIEW")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)
                    Text(labelText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.bottom, 28)
            }
        }
    }

    private static func freshPersonalities() -> [GhostPersonality] {
        (0..<5).map { _ in .random() }
    }
}

// MARK: - AR View (places 5 ghosts in a horizontal arc)
struct GhostPreviewARView: UIViewRepresentable {
    let personalities: [GhostPersonality]

    // 5 positions in a gentle arc, camera-relative, at ~2.3 m distance
    private static let layout: [SIMD3<Float>] = {
        (-2...2).map { i in
            let angle = Float(i) * (.pi / 9)      // ±40° spread
            let dist:  Float = 2.30
            return SIMD3(sin(angle) * dist, -0.10, -cos(angle) * dist)
        }
    }()

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur, .disableFaceOcclusions]

        let config = ARWorldTrackingConfiguration()
        config.planeDetection       = []
        config.environmentTexturing = .automatic
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        buildScene(in: arView, coordinator: context.coordinator)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Rebuild when personalities change (Regenerate tapped)
        context.coordinator.rebuild(personalities: personalities,
                                    layout: Self.layout,
                                    arView: uiView)
    }

    func makeCoordinator() -> PreviewCoordinator { PreviewCoordinator() }

    private func buildScene(in arView: ARView, coordinator: PreviewCoordinator) {
        coordinator.rebuild(personalities: personalities,
                            layout: Self.layout,
                            arView: arView)
    }
}

// MARK: - Preview Coordinator (animation)
final class PreviewCoordinator {
    private var cameraAnchor: AnchorEntity?
    private var ghosts: [(root: Entity, bottomParts: [AnimatedPart], baseY: Float, phaseOffset: Float)] = []
    private var timer: Timer?
    private var phase: Float = 0

    func rebuild(personalities: [GhostPersonality],
                 layout: [SIMD3<Float>],
                 arView: ARView) {
        // Remove old anchor
        if let old = cameraAnchor {
            arView.scene.removeAnchor(old)
        }
        ghosts.removeAll()

        let anchor = AnchorEntity(.camera)
        arView.scene.addAnchor(anchor)
        cameraAnchor = anchor

        for (i, pos) in layout.prefix(personalities.count).enumerated() {
            let personality = personalities[i]
            let (ghostRoot, bottomParts) = makeGhostEntity(skin: .classic, personality: personality)
            ghostRoot.position = pos
            ghostRoot.scale    = SIMD3(repeating: 0.80)
            anchor.addChild(ghostRoot)
            ghosts.append((root: ghostRoot,
                           bottomParts: bottomParts,
                           baseY: pos.y,
                           phaseOffset: Float(i) * (.pi * 2.0 / Float(layout.count))))
        }

        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        phase += Float(1.0 / 60.0) * 1.25

        for (idx, ghost) in ghosts.enumerated() {
            let offset = ghost.phaseOffset
            // Float bob
            ghost.root.position.y = ghost.baseY + sin(phase + offset) * 0.055

            // Gentle tilt + sway per ghost
            let roll = sin(phase * 0.50 + offset) * 0.062
            let yaw  = sin(phase * 0.28 + offset) * 0.032
            ghost.root.orientation = simd_quatf(angle: yaw,  axis: SIMD3(0, 1, 0))
                                   * simd_quatf(angle: roll, axis: SIMD3(0, 0, 1))

            // Hem wave
            let n = Float(ghost.bottomParts.count)
            for (j, part) in ghost.bottomParts.enumerated() {
                let partOffset = Float(j) * (.pi * 2.0 / n)
                let swingAmp   = 0.014 + abs(part.basePosition.x) * 0.060
                let waveY      = sin(phase * 2.1 + partOffset + offset) * 0.020
                let waveX      = cos(phase * 1.4 + partOffset + offset) * swingAmp
                part.entity.position = SIMD3(
                    part.basePosition.x + waveX,
                    part.basePosition.y + waveY,
                    part.basePosition.z
                )
            }

            _ = idx   // suppress unused warning
        }
    }

    deinit { timer?.invalidate() }
}

//
//  ARGhostView.swift
//  urbanghosthunters
//

import SwiftUI
import ARKit
import RealityKit

// MARK: - AR Session Delegate
class GhostARSessionDelegate: NSObject, ARSessionDelegate {
    var onTrackingStateChanged: ((String?) -> Void)?

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            onTrackingStateChanged?(nil)
        case .limited(let reason):
            switch reason {
            case .initializing:
                onTrackingStateChanged?("Initializing AR…")
            case .excessiveMotion:
                onTrackingStateChanged?("Move slower")
            case .insufficientFeatures:
                onTrackingStateChanged?("Point at a surface")
            case .relocalizing:
                onTrackingStateChanged?("Relocalizing…")
            @unknown default:
                onTrackingStateChanged?("Limited tracking")
            }
        case .notAvailable:
            onTrackingStateChanged?("AR unavailable")
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        onTrackingStateChanged?("AR error — restarting")
    }

    func sessionWasInterrupted(_ session: ARSession) {
        onTrackingStateChanged?("AR interrupted")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        onTrackingStateChanged?(nil)
    }
}

// MARK: - AR Ghost View
struct ARGhostView: UIViewRepresentable {
    var proximityLevel: Double
    var showGhost: Bool = true
    var onTrackingMessage: ((String?) -> Void)?
    var onGhostScreenPosition: ((CGPoint) -> Void)?

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        arView.renderOptions = [
            .disableDepthOfField,
            .disableMotionBlur,
            .disableHDR,
            .disableFaceOcclusions
        ]

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []
        config.environmentTexturing = .none

        arView.session.delegate = context.coordinator.sessionDelegate
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        if showGhost {
            // Camera-relative anchor so the ghost never drifts off-screen
            let cameraAnchor = AnchorEntity(.camera)
            arView.scene.addAnchor(cameraAnchor)

            let ghostRoot = buildGhost()
            // Position 1.5m in front of camera, slightly below eye level
            ghostRoot.position = SIMD3(0, -0.18, -1.5)
            cameraAnchor.addChild(ghostRoot)

            context.coordinator.ghostRoot = ghostRoot
            context.coordinator.startAnimation(arView: arView,
                                               onScreenPos: onGhostScreenPosition)
        }

        context.coordinator.arView = arView
        context.coordinator.sessionDelegate.onTrackingStateChanged = { message in
            DispatchQueue.main.async { onTrackingMessage?(message) }
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.currentProximity = Float(max(0, min(1, proximityLevel)))
        context.coordinator.onScreenPos = onGhostScreenPosition
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: Procedural ghost model (same design as GhostARView)
    private func buildGhost() -> Entity {
        let root = Entity()

        var bodyMat = UnlitMaterial()
        bodyMat.color = .init(tint: UIColor(red: 0.80, green: 0.96, blue: 1.00, alpha: 1.0))

        var eyeMat = UnlitMaterial()
        eyeMat.color = .init(tint: UIColor(red: 0.06, green: 0.02, blue: 0.18, alpha: 1.0))

        func part(_ mesh: MeshResource,
                  mat: UnlitMaterial,
                  pos: SIMD3<Float>,
                  scale: SIMD3<Float> = .one) {
            let e = ModelEntity(mesh: mesh, materials: [mat])
            e.position = pos
            e.scale = scale
            root.addChild(e)
        }

        part(.generateSphere(radius: 0.15), mat: bodyMat, pos: SIMD3(0, 0.28, 0))
        part(.generateSphere(radius: 0.135), mat: bodyMat,
             pos: SIMD3(0, 0.05, 0), scale: SIMD3(1.0, 1.7, 0.88))
        part(.generateSphere(radius: 0.060), mat: bodyMat, pos: SIMD3(-0.09, -0.22, 0))
        part(.generateSphere(radius: 0.065), mat: bodyMat, pos: SIMD3(  0.0, -0.28, 0))
        part(.generateSphere(radius: 0.060), mat: bodyMat, pos: SIMD3( 0.09, -0.22, 0))
        part(.generateSphere(radius: 0.038), mat: eyeMat, pos: SIMD3(-0.055, 0.30, 0.12))
        part(.generateSphere(radius: 0.038), mat: eyeMat, pos: SIMD3( 0.055, 0.30, 0.12))

        return root
    }

    // MARK: - Coordinator
    class Coordinator {
        var ghostRoot: Entity?
        var arView: ARView?
        var currentProximity: Float = 1.0
        var onScreenPos: ((CGPoint) -> Void)?
        var animPhase: Float = 0
        var timer: Timer?
        let sessionDelegate = GhostARSessionDelegate()

        func startAnimation(arView: ARView, onScreenPos: ((CGPoint) -> Void)?) {
            self.onScreenPos = onScreenPos
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
        }

        private func tick() {
            guard let root = ghostRoot, let arView else { return }
            animPhase += Float(1.0 / 60.0) * 1.6

            // Absolute sine position — no drift
            root.position.y = -0.18 + sin(animPhase) * 0.05
            root.orientation = simd_quatf(angle: animPhase * 0.25, axis: SIMD3(0, 1, 0))

            let pulse = 0.08 * sin(animPhase * 2.5) * currentProximity
            let level = currentProximity + pulse
            root.components.set(OpacityComponent(opacity: level * 0.9))
            root.scale = SIMD3(repeating: 0.6 + level * 0.9)

            // Project to screen for the seal mechanic
            let worldPos = root.position(relativeTo: nil)
            if let screenPos = arView.project(worldPos) {
                DispatchQueue.main.async { [weak self] in
                    self?.onScreenPos?(screenPos)
                }
            }
        }

        deinit { timer?.invalidate() }
    }
}

// MARK: - Fallback for unsupported devices
struct ARUnsupportedView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.yellow)
                Text("AR not supported on this device")
                    .foregroundStyle(.white)
                    .font(.subheadline)
            }
        }
    }
}

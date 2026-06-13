//
//  ARGhostView.swift
//  urbanghosthunters
//

import SwiftUI
import ARKit
import RealityKit

// MARK: - AR Session Delegate
class GhostARSessionDelegate: NSObject, ARSessionDelegate  {
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

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Performance: disable unnecessary rendering features
        arView.renderOptions = [
            .disableDepthOfField,
            .disableMotionBlur,
            .disableHDR,
            .disableFaceOcclusions
        ]

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]

        // Performance: disable environment texturing to save GPU
        config.environmentTexturing = .none

        arView.session.delegate = context.coordinator.sessionDelegate
        arView.session.run(config)

        // Ghost anchor 1.5m ahead, slightly below eye level
        let anchor = AnchorEntity(world: [0, -0.5, -1.5])

        let ghostMesh = MeshResource.generateSphere(radius: 0.15)
        let ghostMaterial = SimpleMaterial(
            color: UIColor.purple.withAlphaComponent(0.8),
            isMetallic: false
        )
        let ghostEntity = ModelEntity(mesh: ghostMesh, materials: [ghostMaterial])
        anchor.addChild(ghostEntity)
        arView.scene.addAnchor(anchor)

        context.coordinator.ghostEntity = ghostEntity
        context.coordinator.arView = arView

        // Handle tracking state changes
        context.coordinator.sessionDelegate.onTrackingStateChanged = { message in
            DispatchQueue.main.async {
                context.coordinator.trackingMessage = message
            }
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        let scale = Float(0.5 + proximityLevel * 1.5)
        context.coordinator.ghostEntity?.scale = [scale, scale, scale]

        let alpha = CGFloat(0.3 + proximityLevel * 0.7)
        let material = SimpleMaterial(
            color: UIColor.purple.withAlphaComponent(alpha),
            isMetallic: false
        )
        context.coordinator.ghostEntity?.model?.materials = [material]
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var ghostEntity: ModelEntity?
        var arView: ARView?
        var trackingMessage: String?
        let sessionDelegate = GhostARSessionDelegate()
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
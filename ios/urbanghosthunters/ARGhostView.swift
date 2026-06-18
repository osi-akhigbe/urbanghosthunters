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
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .none

        arView.session.delegate = context.coordinator.sessionDelegate
        arView.session.run(config)

        // Ghost anchor 1.5m ahead, slightly below eye level
        let anchor = AnchorEntity(world: [0, -0.3, -1.5])

        let ghostMesh = MeshResource.generateSphere(radius: 0.2)
        var ghostMaterial = SimpleMaterial()
        ghostMaterial.color = .init(tint: UIColor.purple.withAlphaComponent(0.85))
        ghostMaterial.metallic = 0.0
        ghostMaterial.roughness = 0.8

        let ghostEntity = ModelEntity(mesh: ghostMesh, materials: [ghostMaterial])
        anchor.addChild(ghostEntity)
        arView.scene.addAnchor(anchor)

        context.coordinator.ghostEntity = ghostEntity
        context.coordinator.arView = arView

        startFloatAnimation(ghostEntity)

        context.coordinator.sessionDelegate.onTrackingStateChanged = { message in
            DispatchQueue.main.async {
                onTrackingMessage?(message)
            }
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        guard let ghostEntity = context.coordinator.ghostEntity else { return }

        // Scale and opacity grow with proximity
        let scale = Float(0.6 + proximityLevel * 1.4)
        ghostEntity.scale = [scale, scale, scale]

        let alpha = CGFloat(0.4 + proximityLevel * 0.6)
        var material = SimpleMaterial()
        material.color = .init(tint: UIColor.purple.withAlphaComponent(alpha))
        material.metallic = 0.0
        material.roughness = 0.8
        ghostEntity.model?.materials = [material]

        // Project ghost world position to screen so the seal can target it
        let worldPos = ghostEntity.position(relativeTo: nil)
        if let screenPos = uiView.project(worldPos) {
            onGhostScreenPosition?(screenPos)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var ghostEntity: ModelEntity?
        var arView: ARView?
        let sessionDelegate = GhostARSessionDelegate()
    }

    // Float up/down relative to the anchor so there's no drift
    private func startFloatAnimation(_ entity: ModelEntity) {
        let up = Transform(translation: [0, 0.12, 0])
        entity.move(to: up, relativeTo: entity.parent, duration: 1.2, timingFunction: .easeInOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak entity] in
            guard let entity else { return }
            loopFloat(entity, goingUp: false)
        }
    }

    private func loopFloat(_ entity: ModelEntity, goingUp: Bool) {
        let offset: Float = goingUp ? 0.12 : -0.12
        let target = Transform(translation: [0, offset, 0])
        entity.move(to: target, relativeTo: entity.parent, duration: 1.2, timingFunction: .easeInOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak entity] in
            guard let entity else { return }
            loopFloat(entity, goingUp: !goingUp)
        }
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

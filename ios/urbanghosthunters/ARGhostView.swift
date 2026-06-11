//
//  ARGhostView.swift
//  urbanghosthunters
//

import SwiftUI
import ARKit
import RealityKit

struct ARGhostView: UIViewRepresentable {
    var proximityLevel: Double

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Basic world tracking config
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)

        // Place a ghost anchor 1.5m in front of the user
        let anchor = AnchorEntity(world: [0, -0.5, -1.5])

        // Ghost mesh — glowing sphere as placeholder until .usdz is ready
        let ghostMesh = MeshResource.generateSphere(radius: 0.15)
        let ghostMaterial = SimpleMaterial(
            color: UIColor.purple.withAlphaComponent(0.8),
            isMetallic: false
        )
        let ghostEntity = ModelEntity(mesh: ghostMesh, materials: [ghostMaterial])

        // Floating animation
        let floatUp = Transform(translation: [0, 0.1, 0])
        let floatDown = Transform(translation: [0, -0.1, 0])
        ghostEntity.move(to: floatUp, relativeTo: ghostEntity, duration: 1.0, timingFunction: .easeInOut)

        anchor.addChild(ghostEntity)
        arView.scene.addAnchor(anchor)

        context.coordinator.ghostEntity = ghostEntity
        context.coordinator.arView = arView

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Scale ghost based on proximity — bigger and brighter as you get closer
        let scale = Float(0.5 + proximityLevel * 1.5)
        context.coordinator.ghostEntity?.scale = [scale, scale, scale]

        // Update opacity based on proximity
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
    }
}

// Fallback view for devices that don't support AR
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
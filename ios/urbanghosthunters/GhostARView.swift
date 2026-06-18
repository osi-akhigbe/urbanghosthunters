import SwiftUI
import RealityKit

// A RealityKit non-AR view that renders a procedural ghost entity.
// The ghost is built entirely from primitive sphere meshes — no external .usdz asset required,
// though you can swap in one via Entity.loadModel(named:) if desired.
//
// Visibility (OpacityComponent) and scale grow with proximityLevel (0–1) so the ghost
// appears to materialise out of the dark as the player approaches the hotspot.
struct GhostARView: UIViewRepresentable {
    let proximityLevel: Double

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero,
                           cameraMode: .nonAR,
                           automaticallyConfigureSession: false)
        arView.backgroundColor = .clear
        arView.environment.background = .color(.clear)

        context.coordinator.setup(arView: arView)
        context.coordinator.updateProximity(proximityLevel)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateProximity(proximityLevel)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
}

// MARK: - Coordinator

extension GhostARView {
    @MainActor
    final class Coordinator {
        private var ghostRoot: Entity?
        private var animPhase: Float = 0
        private var currentProximity: Float = 0
        private var timer: Timer?

        func setup(arView: ARView) {
            // Camera at origin, looking -Z toward the ghost
            let cameraAnchor = AnchorEntity(world: .zero)
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 60
            cameraAnchor.addChild(camera)
            arView.scene.addAnchor(cameraAnchor)

            // Ghost anchored 2 m in front of the camera
            let ghostAnchor = AnchorEntity(world: SIMD3(0, 0, -2.0))
            let root = buildGhost()
            ghostAnchor.addChild(root)
            arView.scene.addAnchor(ghostAnchor)
            ghostRoot = root

            // 60 fps animation timer — created on main thread so it fires on the main RunLoop
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        }

        // MARK: Ghost construction

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

            // Head
            part(.generateSphere(radius: 0.15), mat: bodyMat, pos: SIMD3(0, 0.28, 0))

            // Body — stretched vertically and slightly flattened in Z
            part(.generateSphere(radius: 0.135), mat: bodyMat,
                 pos: SIMD3(0, 0.05, 0), scale: SIMD3(1.0, 1.7, 0.88))

            // Tail wisps (three bottom spheres for the classic ghost silhouette)
            part(.generateSphere(radius: 0.060), mat: bodyMat, pos: SIMD3(-0.09, -0.22, 0))
            part(.generateSphere(radius: 0.065), mat: bodyMat, pos: SIMD3(  0.0, -0.28, 0))
            part(.generateSphere(radius: 0.060), mat: bodyMat, pos: SIMD3( 0.09, -0.22, 0))

            // Eyes
            part(.generateSphere(radius: 0.038), mat: eyeMat, pos: SIMD3(-0.055, 0.30, 0.12))
            part(.generateSphere(radius: 0.038), mat: eyeMat, pos: SIMD3( 0.055, 0.30, 0.12))

            return root
        }

        // MARK: Animation

        private func tick() {
            guard let root = ghostRoot else { return }
            animPhase += Float(1.0 / 60.0) * 1.6

            // Float up and down on a sine wave
            root.position.y = sin(animPhase) * 0.05

            // Slow rotation around Y axis
            root.orientation = simd_quatf(angle: animPhase * 0.25,
                                          axis: SIMD3(0, 1, 0))

            // Subtle breathing pulse layered on top of the proximity level
            let pulse = 0.08 * sin(animPhase * 2.5) * currentProximity
            applyAppearance(currentProximity + pulse)
        }

        // MARK: Proximity binding

        func updateProximity(_ level: Double) {
            currentProximity = Float(max(0.0, min(1.0, level)))
        }

        private func applyAppearance(_ level: Float) {
            guard let root = ghostRoot else { return }

            // Opacity: invisible at level=0, 90% solid at level=1
            root.components.set(OpacityComponent(opacity: level * 0.9))

            // Scale: ghost grows from half-size to full as the player closes in
            root.scale = SIMD3(repeating: 0.6 + level * 0.9)
        }

        deinit { timer?.invalidate() }
    }
}

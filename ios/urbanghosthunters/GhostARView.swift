import SwiftUI
import RealityKit

struct GhostARView: UIViewRepresentable {
    let proximityLevel: Double
    var skin: GhostSkin = .classic

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero,
                           cameraMode: .nonAR,
                           automaticallyConfigureSession: false)
        arView.backgroundColor = .clear
        arView.environment.background = .color(.clear)

        context.coordinator.setup(arView: arView, skin: skin)
        context.coordinator.updateProximity(proximityLevel)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateProximity(proximityLevel)
        context.coordinator.updateSkinIfNeeded(skin)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
}

// MARK: - Coordinator

extension GhostARView {
    @MainActor
    final class Coordinator {
        private var ghostRoot: Entity?
        private var ghostAnchor: AnchorEntity?
        private var currentSkin: GhostSkin = .classic
        private var animPhase: Float = 0
        private var currentProximity: Float = 0
        private var timer: Timer?

        func setup(arView: ARView, skin: GhostSkin) {
            let cameraAnchor = AnchorEntity(world: .zero)
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 60
            cameraAnchor.addChild(camera)
            arView.scene.addAnchor(cameraAnchor)

            let anchor = AnchorEntity(world: SIMD3(0, 0, -2.0))
            let root = buildGhost(skin: skin)
            anchor.addChild(root)
            arView.scene.addAnchor(anchor)

            ghostAnchor = anchor
            ghostRoot = root
            currentSkin = skin

            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        }

        func updateProximity(_ level: Double) {
            currentProximity = Float(max(0.0, min(1.0, level)))
        }

        func updateSkinIfNeeded(_ skin: GhostSkin) {
            guard skin != currentSkin, let anchor = ghostAnchor else { return }
            if let old = ghostRoot { anchor.removeChild(old) }
            let newRoot = buildGhost(skin: skin)
            anchor.addChild(newRoot)
            ghostRoot = newRoot
            currentSkin = skin
        }

        // MARK: Ghost construction

        private func buildGhost(skin: GhostSkin) -> Entity {
            let root = Entity()

            var bodyMat = UnlitMaterial()
            bodyMat.color = .init(tint: skin.bodyUIColor)

            var eyeMat = UnlitMaterial()
            eyeMat.color = .init(tint: skin.eyeUIColor)

            func part(_ mesh: MeshResource,
                      mat: UnlitMaterial,
                      pos: SIMD3<Float>,
                      scale: SIMD3<Float> = .one) {
                let e = ModelEntity(mesh: mesh, materials: [mat])
                e.position = pos
                e.scale = scale
                root.addChild(e)
            }

            part(.generateSphere(radius: 0.15),  mat: bodyMat, pos: SIMD3(0, 0.28, 0))
            part(.generateSphere(radius: 0.135), mat: bodyMat,
                 pos: SIMD3(0, 0.05, 0), scale: SIMD3(1.0, 1.7, 0.88))
            part(.generateSphere(radius: 0.060), mat: bodyMat, pos: SIMD3(-0.09, -0.22, 0))
            part(.generateSphere(radius: 0.065), mat: bodyMat, pos: SIMD3(  0.0, -0.28, 0))
            part(.generateSphere(radius: 0.060), mat: bodyMat, pos: SIMD3( 0.09, -0.22, 0))
            part(.generateSphere(radius: 0.038), mat: eyeMat,  pos: SIMD3(-0.055, 0.30, 0.12))
            part(.generateSphere(radius: 0.038), mat: eyeMat,  pos: SIMD3( 0.055, 0.30, 0.12))

            return root
        }

        // MARK: Animation

        private func tick() {
            guard let root = ghostRoot else { return }
            animPhase += Float(1.0 / 60.0) * 1.6
            root.position.y = sin(animPhase) * 0.05
            root.orientation = simd_quatf(angle: animPhase * 0.25, axis: SIMD3(0, 1, 0))
            let pulse = 0.08 * sin(animPhase * 2.5) * currentProximity
            applyAppearance(currentProximity + pulse)
        }

        private func applyAppearance(_ level: Float) {
            guard let root = ghostRoot else { return }
            root.components.set(OpacityComponent(opacity: level * 0.9))
            root.scale = SIMD3(repeating: 0.6 + level * 0.9)
        }

        deinit { timer?.invalidate() }
    }
}

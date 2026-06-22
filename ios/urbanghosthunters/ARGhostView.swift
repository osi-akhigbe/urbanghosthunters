//
//  ARGhostView.swift
//  urbanghosthunters
//

import SwiftUI
import ARKit
import RealityKit

// GhostSkin enum lives in GhostSkin.swift (added by remote team)

// MARK: - Ghost Personality (shape + expression, randomised per encounter)
struct GhostPersonality {
    enum EyeShape    { case oval, round, wide }
    enum Expression  { case neutral, startled, friendly, menacing }

    var eyeShape:       EyeShape    = .oval
    var expression:     Expression  = .neutral
    var waveCount:      Int         = 5
    var wavePhase:      Float       = 0
    var waveAmplitude:  Float       = 0.022
    var bodyWidthScale: Float       = 1.0
    var hasMouth:       Bool        = false

    static func random() -> GhostPersonality {
        var p = GhostPersonality()
        p.eyeShape       = [.oval, .round, .wide].randomElement()!
        p.expression     = [.neutral, .startled, .friendly, .menacing].randomElement()!
        p.waveCount      = Int.random(in: 4...6)
        p.wavePhase      = Float.random(in: 0 ... .pi * 2)
        p.waveAmplitude  = Float.random(in: 0.014...0.028)
        p.bodyWidthScale = Float.random(in: 0.92...1.10)
        p.hasMouth       = Bool.random()
        return p
    }
}

// MARK: - Animated Part (for per-frame hem wave)
struct AnimatedPart {
    let entity: Entity
    let basePosition: SIMD3<Float>
}

// MARK: - Ghost Entity Factory (shared by AR view + preview)
func makeGhostEntity(skin: GhostSkin,
                     personality p: GhostPersonality) -> (root: Entity, bottomParts: [AnimatedPart]) {
    let root = Entity()

    // Body: PhysicallyBasedMaterial — soft matte shading that reacts to AR lighting
    var bodyMat = PhysicallyBasedMaterial()
    bodyMat.baseColor = PhysicallyBasedMaterial.BaseColor(tint: skin.bodyUIColor)
    bodyMat.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.88)
    bodyMat.metallic  = PhysicallyBasedMaterial.Metallic(floatLiteral: 0.00)

    // Face: UnlitMaterial so eyes/mouth stay true-black regardless of lighting
    var faceMat = UnlitMaterial()
    faceMat.color = .init(tint: skin.eyeUIColor)

    // Dark hollow — simulates the open underside of the draped sheet
    var hollowMat = UnlitMaterial()
    hollowMat.color = .init(tint: UIColor(white: 0.03, alpha: 1))

    func addBody(_ mesh: MeshResource, pos: SIMD3<Float>, scale: SIMD3<Float> = .one) {
        let e = ModelEntity(mesh: mesh, materials: [bodyMat])
        e.position = pos; e.scale = scale; root.addChild(e)
    }
    @discardableResult
    func addFace(_ mesh: MeshResource, pos: SIMD3<Float>, scale: SIMD3<Float> = .one) -> ModelEntity {
        let e = ModelEntity(mesh: mesh, materials: [faceMat])
        e.position = pos; e.scale = scale; root.addChild(e)
        return e
    }

    // ── HEAD DOME ─────────────────────────────────────────────────
    addBody(.generateSphere(radius: 0.200),
            pos: SIMD3(0, 0.190, 0),
            scale: SIMD3(1.00, 1.00, 0.82))

    // ── BODY — bell that widens below the head ─────────────────────
    addBody(.generateSphere(radius: 0.190),
            pos: SIMD3(0, -0.030, 0),
            scale: SIMD3(p.bodyWidthScale * 1.18, 1.70, 0.78))

    addBody(.generateSphere(radius: 0.198),
            pos: SIMD3(0, -0.245, 0),
            scale: SIMD3(p.bodyWidthScale * 1.52, 0.72, 0.72))

    // ── DARK INTERIOR (open underside) ─────────────────────────────
    let hollow = ModelEntity(mesh: .generateSphere(radius: 0.150), materials: [hollowMat])
    hollow.position = SIMD3(0, -0.316, 0)
    hollow.scale    = SIMD3(1.40, 0.17, 0.66)
    root.addChild(hollow)

    // ── SCALLOPED HEM — N softly-rounded lobes in a sine arc ───────
    let hemSpan: Float = 0.208 * p.bodyWidthScale
    var bottomParts: [AnimatedPart] = []
    for i in 0..<p.waveCount {
        let t        = p.waveCount > 1 ? Float(i) / Float(p.waveCount - 1) : 0.5
        let x        = -hemSpan + t * hemSpan * 2.0
        let waveY    = p.waveAmplitude * sin(t * .pi * Float(p.waveCount - 1) + p.wavePhase)
        let edgeFade = 1.0 - abs(t - 0.5) * 0.32
        let r: Float = 0.075 * Float(edgeFade)
        let yScale   = Float(1.42 * edgeFade + 0.08)
        let lobe     = ModelEntity(mesh: .generateSphere(radius: r), materials: [bodyMat])
        let base     = SIMD3<Float>(x, -0.296 + waveY, 0)
        lobe.position = base
        lobe.scale    = SIMD3(0.80, yScale, 0.62)
        root.addChild(lobe)
        bottomParts.append(AnimatedPart(entity: lobe, basePosition: base))
    }

    // ── EYES ───────────────────────────────────────────────────────
    let eyeY: Float = 0.205
    let eyeZ: Float = 0.148
    let eyeX: Float = 0.060

    let (eyeXScale, eyeYScale, eyeRadius): (Float, Float, Float) = {
        switch (p.eyeShape, p.expression) {
        case (_, .startled): return (1.05, 1.18, 0.043)
        case (.oval,  _):    return (0.80, 1.20, 0.038)
        case (.round, _):    return (1.00, 1.00, 0.040)
        case (.wide,  _):    return (1.38, 0.70, 0.038)
        }
    }()

    let eyeTilt: Float = {
        switch p.expression {
        case .menacing: return  .pi * 0.22
        case .friendly: return -.pi * 0.14
        default:        return 0
        }
    }()

    let leftEye = addFace(.generateSphere(radius: eyeRadius),
                          pos: SIMD3(-eyeX, eyeY, eyeZ),
                          scale: SIMD3(eyeXScale, eyeYScale, 0.46))
    leftEye.orientation = simd_quatf(angle:  eyeTilt, axis: SIMD3(0, 0, 1))

    let rightEye = addFace(.generateSphere(radius: eyeRadius),
                           pos: SIMD3( eyeX, eyeY, eyeZ),
                           scale: SIMD3(eyeXScale, eyeYScale, 0.46))
    rightEye.orientation = simd_quatf(angle: -eyeTilt, axis: SIMD3(0, 0, 1))

    // ── MOUTH (optional) ───────────────────────────────────────────
    let showMouth = p.hasMouth || p.expression == .startled || p.expression == .menacing
    if showMouth {
        let (mxScale, myScale): (Float, Float) = {
            switch p.expression {
            case .startled: return (1.15, 1.10)
            case .menacing: return (1.95, 0.46)
            case .friendly: return (1.58, 0.56)
            default:        return (1.12, 0.72)
            }
        }()
        addFace(.generateSphere(radius: 0.026),
                pos: SIMD3(0, eyeY - 0.088, eyeZ),
                scale: SIMD3(mxScale, myScale, 0.40))
    }

    return (root, bottomParts)
}

// MARK: - AR Session Delegate
class GhostARSessionDelegate: NSObject, ARSessionDelegate {
    var onTrackingStateChanged: ((String?) -> Void)?

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            onTrackingStateChanged?(nil)
        case .limited(let reason):
            switch reason {
            case .initializing:         onTrackingStateChanged?("Initializing AR…")
            case .excessiveMotion:      onTrackingStateChanged?("Move slower")
            case .insufficientFeatures: onTrackingStateChanged?("Point at a surface")
            case .relocalizing:         onTrackingStateChanged?("Relocalizing…")
            @unknown default:           onTrackingStateChanged?("Limited tracking")
            }
        case .notAvailable:
            onTrackingStateChanged?("AR unavailable")
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) { onTrackingStateChanged?("AR error") }
    func sessionWasInterrupted(_ session: ARSession)    { onTrackingStateChanged?("AR interrupted") }
    func sessionInterruptionEnded(_ session: ARSession) { onTrackingStateChanged?(nil) }
}

// MARK: - AR Ghost View
struct ARGhostView: UIViewRepresentable {
    var proximityLevel: Double
    var showGhost: Bool = true
    var skin: GhostSkin = .classic
    var onTrackingMessage: ((String?) -> Void)?
    var onGhostScreenPosition: ((CGPoint) -> Void)?

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.renderOptions = [
            .disableDepthOfField,
            .disableMotionBlur,
            .disableFaceOcclusions
        ]

        let config = ARWorldTrackingConfiguration()
        config.planeDetection       = []
        config.environmentTexturing = .automatic

        arView.session.delegate = context.coordinator.sessionDelegate
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        if showGhost {
            let cameraAnchor = AnchorEntity(.camera)
            arView.scene.addAnchor(cameraAnchor)

            let personality = context.coordinator.personality
            let (ghostRoot, bottomParts) = makeGhostEntity(skin: skin, personality: personality)
            ghostRoot.position = SIMD3(0, -0.15, -1.5)
            cameraAnchor.addChild(ghostRoot)

            context.coordinator.ghostRoot    = ghostRoot
            context.coordinator.cameraAnchor = cameraAnchor
            context.coordinator.bottomParts  = bottomParts
            context.coordinator.currentSkin  = skin
            context.coordinator.startAnimation(arView: arView, onScreenPos: onGhostScreenPosition)
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
        context.coordinator.updateSkinIfNeeded(skin)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator
    class Coordinator {
        let personality = GhostPersonality.random()

        var ghostRoot: Entity?
        var cameraAnchor: AnchorEntity?
        var arView: ARView?
        var currentProximity: Float = 1.0
        var currentSkin: GhostSkin = .classic
        var onScreenPos: ((CGPoint) -> Void)?
        var animPhase: Float = 0
        var timer: Timer?
        var bottomParts: [AnimatedPart] = []
        let sessionDelegate = GhostARSessionDelegate()

        func updateSkinIfNeeded(_ skin: GhostSkin) {
            guard skin != currentSkin, let anchor = cameraAnchor else { return }
            if let old = ghostRoot { anchor.removeChild(old) }
            let (newRoot, newParts) = makeGhostEntity(skin: skin, personality: personality)
            newRoot.position = SIMD3(0, -0.15, -1.5)
            anchor.addChild(newRoot)
            ghostRoot    = newRoot
            bottomParts  = newParts
            currentSkin  = skin
        }

        func startAnimation(arView: ARView, onScreenPos: ((CGPoint) -> Void)?) {
            self.onScreenPos = onScreenPos
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
        }

        private func tick() {
            guard let root = ghostRoot, let arView else { return }
            animPhase += Float(1.0 / 60.0) * 1.3

            root.position.y = -0.15 + sin(animPhase) * 0.068

            let roll = sin(animPhase * 0.52) * 0.070
            let yaw  = sin(animPhase * 0.31) * 0.036
            root.orientation = simd_quatf(angle: yaw,  axis: SIMD3(0, 1, 0))
                             * simd_quatf(angle: roll, axis: SIMD3(0, 0, 1))

            let pulse = 0.055 * sin(animPhase * 2.1) * currentProximity
            let level = max(0.15, currentProximity + pulse)
            root.components.set(OpacityComponent(opacity: level * 0.93))
            root.scale = SIMD3(repeating: 0.78 + level * 0.13)

            let n = Float(bottomParts.count)
            for (i, part) in bottomParts.enumerated() {
                let offset   = Float(i) * (.pi * 2.0 / n)
                let swingAmp = 0.016 + abs(part.basePosition.x) * 0.065
                let waveY    = sin(animPhase * 2.2 + offset) * 0.024
                let waveX    = cos(animPhase * 1.5 + offset) * swingAmp
                part.entity.position = SIMD3(
                    part.basePosition.x + waveX,
                    part.basePosition.y + waveY,
                    part.basePosition.z
                )
            }

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

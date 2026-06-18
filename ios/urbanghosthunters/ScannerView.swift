<<<<<<< HEAD
//
//  ScannerView.swift
//  urbanghosthunters
//

=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
import SwiftUI
import CoreLocation
import CoreHaptics

<<<<<<< HEAD
// MARK: - ViewModel
@Observable
@MainActor
final class ScannerViewModel: NSObject, CLLocationManagerDelegate {
<<<<<<< HEAD
    var headingAlignment: Double = 0
    var proximityLevel: Double = 0
=======
    var headingAlignment: Double = 0      // 0-1 (1 = perfectly aligned)
    var proximityLevel: Double = 0        // 0-1 (1 = very close)
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
@Observable
@MainActor
final class ScannerViewModel: NSObject, CLLocationManagerDelegate {
    var headingAlignment: Double = 0
    var proximityLevel: Double = 0
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    var headingDegrees: Double = 0
    var distanceMeters: Double = 0
    var errorText: String?

    private let locationManager = CLLocationManager()
    private var hapticEngine: CHHapticEngine?
    private var hapticTimer: Timer?
    let hotspot: Hotspot

    init(hotspot: Hotspot) {
        self.hotspot = hotspot
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        prepareHaptics()
    }

<<<<<<< HEAD
=======
    // Stops location and haptic updates when the view disappears
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        stopHaptics()
    }

<<<<<<< HEAD
<<<<<<< HEAD
=======
    // MARK: - Bearing calculation
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
    // Returns the compass bearing in degrees from a user coordinate to the hotspot
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    private func bearingTo(lat: Double, lng: Double, from userLat: Double, userLng: Double) -> Double {
        let dLng = (lng - userLng) * .pi / 180
        let lat1 = userLat * .pi / 180
        let lat2 = lat * .pi / 180
        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

<<<<<<< HEAD
<<<<<<< HEAD
=======
    // MARK: - Location delegate
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
    // Updates distance and proximity level whenever the user's location changes
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            let hotspotLoc = CLLocation(latitude: self.hotspot.lat, longitude: self.hotspot.lng)
            let distance = loc.distance(from: hotspotLoc)
            self.distanceMeters = distance
<<<<<<< HEAD
<<<<<<< HEAD
=======
            // Proximity 0-1: full signal within 10m, zero at 200m+
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
            self.proximityLevel = max(0, min(1, 1 - (distance - 10) / 190))
            self.updateHapticRate()
        }
    }

<<<<<<< HEAD
=======
    // Updates heading alignment score whenever the device heading changes.
    // The Reveal Lens totem doubles the acceptance window from ±45° to ±90°.
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            self.headingDegrees = newHeading.magneticHeading
            let bearing = self.bearingTo(
                lat: self.hotspot.lat,
                lng: self.hotspot.lng,
                from: self.locationManager.location?.coordinate.latitude ?? 0,
                userLng: self.locationManager.location?.coordinate.longitude ?? 0
            )
<<<<<<< HEAD
<<<<<<< HEAD
=======
            // Alignment 0-1: 1 = facing hotspot directly
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
            let diff = abs(newHeading.magneticHeading - bearing)
            let normalised = min(diff, 360 - diff)
            self.headingAlignment = max(0, 1 - normalised / 45)
=======
            let diff = abs(newHeading.magneticHeading - bearing)
            let normalised = min(diff, 360 - diff)
            let window = 45.0 + InventoryViewModel.shared.effects.alignmentWindowBonus
            self.headingAlignment = max(0, 1 - normalised / window)
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
            self.updateHapticRate()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in self.errorText = error.localizedDescription }
    }

<<<<<<< HEAD
<<<<<<< HEAD
=======
    // MARK: - Haptics
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
    // Prepares the haptic engine on devices that support it
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        try? hapticEngine?.start()
    }

<<<<<<< HEAD
=======
    // Reschedules the haptic pulse timer based on combined proximity + alignment.
    // Spirit Flash totem halves the pulse interval, giving faster feedback.
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    func updateHapticRate() {
        hapticTimer?.invalidate()
        let combined = (proximityLevel + headingAlignment) / 2
        guard combined > 0.1 else { return }
<<<<<<< HEAD
        let interval = max(0.15, 1.5 - combined * 1.35)
=======
        let baseInterval = max(0.15, 1.5 - combined * 1.35)
        let reduction = InventoryViewModel.shared.effects.cooldownReduction
        let interval = baseInterval * (1 - reduction)
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
        hapticTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.pulseHaptic()
        }
    }

<<<<<<< HEAD
=======
    // Fires a single haptic pulse scaled to the current signal strength
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    func pulseHaptic() {
        guard let engine = hapticEngine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                               value: Float((proximityLevel + headingAlignment) / 2))
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [intensity, sharpness], relativeTime: 0)
        if let pattern = try? CHHapticPattern(events: [event], parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: 0)
        }
    }

<<<<<<< HEAD
=======
    // Cancels and clears the haptic pulse timer
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    func stopHaptics() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }
}

<<<<<<< HEAD
// MARK: - Scanner View
struct ScannerView: View {
    let hotspot: Hotspot
    @State private var vm: ScannerViewModel
<<<<<<< HEAD
    @State private var micLure = MicLureManager()
    @State private var showContainment = false
    @State private var audioStatic = AudioStaticManager()
    @Environment(\.dismiss) private var dismiss

    private var canBeginContainment: Bool {
        vm.proximityLevel > 0.3 || micLure.revealLevel >= 0.55
    }

=======
    @State private var showContainment = false
    @Environment(\.dismiss) private var dismiss

>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
struct ScannerView: View {
    let hotspot: Hotspot
    @State private var vm: ScannerViewModel
    @State private var showContainment = false
    @Environment(\.dismiss) private var dismiss

    // Spirit Flash totem lowers the proximity threshold needed to start containment
    private var containmentThreshold: Double {
        let reduction = InventoryViewModel.shared.effects.cooldownReduction
        return max(0.15, 0.3 - reduction * 0.15)
    }

>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    init(hotspot: Hotspot) {
        self.hotspot = hotspot
        _vm = State(initialValue: ScannerViewModel(hotspot: hotspot))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

<<<<<<< HEAD
<<<<<<< HEAD
=======
            // Background grid
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
            GridPattern()
                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                .ignoresSafeArea()

            VStack(spacing: 0) {
<<<<<<< HEAD

<<<<<<< HEAD
=======
                // Top HUD
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SCANNER")
                            .font(.caption).bold()
                            .foregroundStyle(.purple)
                        Text(hotspot.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Difficulty \(hotspot.difficulty)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(vm.distanceMeters))m")
                            .font(.title2).bold()
                            .foregroundStyle(.green)
                            .monospacedDigit()
                        Text("DISTANCE")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding()

<<<<<<< HEAD
                Spacer()

<<<<<<< HEAD
=======
                // Compass meter
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
                ActiveEffectsBar()

                Spacer()

>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                VStack(spacing: 8) {
                    Text("HEADING ALIGNMENT")
                        .font(.caption2).bold()
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)
<<<<<<< HEAD
<<<<<<< HEAD
                    CompassMeter(alignment: vm.headingAlignment, degrees: vm.headingDegrees)
=======

                    CompassMeter(alignment: vm.headingAlignment,
                                 degrees: vm.headingDegrees)
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======

                    CompassMeter(alignment: vm.headingAlignment, degrees: vm.headingDegrees)
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                        .frame(height: 60)
                        .padding(.horizontal)
                }

                Spacer()

<<<<<<< HEAD
<<<<<<< HEAD
=======
                // Proximity meter
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                VStack(spacing: 8) {
                    Text("PROXIMITY SIGNAL")
                        .font(.caption2).bold()
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)
<<<<<<< HEAD
<<<<<<< HEAD
=======

>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======

>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                    ProximityMeter(level: vm.proximityLevel)
                        .frame(height: 24)
                        .padding(.horizontal)
                }

<<<<<<< HEAD
<<<<<<< HEAD
                // Mic lure (APPDEV-32)
                VStack(spacing: 8) {
                    Text("GHOST REVEAL")
                        .font(.caption2).bold()
                        .foregroundStyle(.white.opacity(0.5))
                    ProximityMeter(level: micLure.revealLevel)
                        .frame(height: 20)
                        .padding(.horizontal)
                    Text("Hold to lure — louder = faster reveal")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                    MicLureButton(micLure: micLure)
                        .padding(.horizontal)
                }
                .padding(.vertical, 8)

                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<8, id: \.self) { i in
=======
                Spacer()

                // Signal strength indicator
                HStack(spacing: 4) {
                    ForEach(0..<8) { i in
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<8) { i in
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                        let combined = (vm.proximityLevel + vm.headingAlignment) / 2
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Double(i) / 8.0 < combined ? Color.green : Color.white.opacity(0.1))
                            .frame(width: 20, height: Double(i + 1) * 4 + 8)
                    }
                }
                .padding()

                Spacer()

<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
=======
                // Contain button
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
=======
                // Nearby agents
                NearbyAgentsView()
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
>>>>>>> origin/Osi/feature/APPDEV-49-ble-nearby-agents
                Button {
                    showContainment = true
                } label: {
                    Text("BEGIN CONTAINMENT")
                        .font(.headline).bold()
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
<<<<<<< HEAD
<<<<<<< HEAD
                        .background(canBeginContainment ? Color.purple : Color.gray.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canBeginContainment)
                .padding()

                if !canBeginContainment {
                    VStack(spacing: 8) {
                        Text("Get closer to begin containment")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))

                        Button("Demo: start containment anyway") {
                            showContainment = true
                        }
                        .font(.caption)
                        .foregroundStyle(.purple)
                    }
                    .padding(.bottom, 8)
=======
                        .background(
                            vm.proximityLevel > 0.3
=======
                        .background(
                            vm.proximityLevel > containmentThreshold
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                                ? Color.purple
                                : Color.gray.opacity(0.3)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
<<<<<<< HEAD
                .disabled(vm.proximityLevel <= 0.3)
                .padding()

                if vm.proximityLevel <= 0.3 {
=======
                .disabled(vm.proximityLevel <= containmentThreshold)
                .padding()

                if vm.proximityLevel <= containmentThreshold {
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                    Text("Get closer to begin containment")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 8)
<<<<<<< HEAD
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("← Exit") { dismiss() }
                    .foregroundStyle(.purple)
            }
        }
<<<<<<< HEAD
<<<<<<< HEAD
        .onAppear {
    micLure.prepare()
    audioStatic.prepare()
}
.onChange(of: vm.proximityLevel) { _, newValue in
    audioStatic.setProximity(newValue)
}
        .onDisappear {
    vm.stop()
    micLure.stop()
    audioStatic.stop()
}
<<<<<<< HEAD
=======
        .onDisappear { vm.stop() }
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
        .onDisappear { vm.stop() }
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
        .fullScreenCover(isPresented: $showContainment) {
            ContainmentView(hotspot: hotspot)
        }
    }
=======
    .fullScreenCover(isPresented: $showContainment) {
   ContainmentView(hotspot: hotspot, proximityLevel: vm.proximityLevel)
}
}
>>>>>>> origin/Osi/feature/APPDEV-49-ble-nearby-agents
}

<<<<<<< HEAD
// MARK: - Compass Meter
=======
// Shows a compact strip of currently active totem effects
private struct ActiveEffectsBar: View {
    private var effects: TotemEffects { InventoryViewModel.shared.effects }

    var body: some View {
        let active = InventoryViewModel.shared.equippedTotems
        if !active.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(active) { totem in
                        Label(totem.type.displayName, systemImage: totem.type.icon)
                            .font(.caption2).bold()
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.15),
                                        in: Capsule())
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 4)
        }
    }
}

>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
struct CompassMeter: View {
    let alignment: Double
    let degrees: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
<<<<<<< HEAD
<<<<<<< HEAD
=======
                // Track
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 8)

<<<<<<< HEAD
<<<<<<< HEAD
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.purple.opacity(0.5), .purple],
                                             startPoint: .leading, endPoint: .trailing))
=======
                // Fill
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(colors: [.purple.opacity(0.5), .purple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
<<<<<<< HEAD
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                        .frame(width: geo.size.width * alignment, height: 8)
                    Spacer(minLength: 0)
                }

<<<<<<< HEAD
<<<<<<< HEAD
=======
                // Degree label
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                HStack {
                    Spacer()
                    Text("\(Int(degrees))°")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.trailing, 4)
                }
            }
        }
    }
}

<<<<<<< HEAD
<<<<<<< HEAD
struct MicLureButton: View {
    let micLure: MicLureManager

    var body: some View {
        Text(micLure.isHolding ? "LURING…" : "HOLD TO LURE")
            .font(.headline).bold()
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(micLure.isHolding ? Color.green.opacity(0.8) : Color.purple.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !micLure.isHolding { micLure.beginLure() }
                    }
                    .onEnded { _ in micLure.endLure() }
            )
    }
}

=======
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
// MARK: - Proximity Meter
struct ProximityMeter: View {
    let level: Double

=======
struct ProximityMeter: View {
    let level: Double

    // Color shifts from red → yellow → green as signal strengthens
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
    private var meterColor: Color {
        if level > 0.7 { return .green }
        if level > 0.4 { return .yellow }
        return .red
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
<<<<<<< HEAD
<<<<<<< HEAD
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [meterColor.opacity(0.6), meterColor],
                                         startPoint: .leading, endPoint: .trailing))
=======
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(colors: [meterColor.opacity(0.6), meterColor],
                                       startPoint: .leading, endPoint: .trailing)
                    )
<<<<<<< HEAD
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
=======
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                    .frame(width: geo.size.width * level)
                    .animation(.easeInOut(duration: 0.3), value: level)
            }
        }
    }
}

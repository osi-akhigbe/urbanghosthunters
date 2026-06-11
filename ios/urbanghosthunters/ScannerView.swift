import SwiftUI
import CoreLocation
import CoreHaptics

@Observable
@MainActor
final class ScannerViewModel: NSObject, CLLocationManagerDelegate {
    var headingAlignment: Double = 0
    var proximityLevel: Double = 0
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

    // Stops location and haptic updates when the view disappears
    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        stopHaptics()
    }

    // Returns the compass bearing in degrees from a user coordinate to the hotspot
    private func bearingTo(lat: Double, lng: Double, from userLat: Double, userLng: Double) -> Double {
        let dLng = (lng - userLng) * .pi / 180
        let lat1 = userLat * .pi / 180
        let lat2 = lat * .pi / 180
        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    // Updates distance and proximity level whenever the user's location changes
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            let hotspotLoc = CLLocation(latitude: self.hotspot.lat, longitude: self.hotspot.lng)
            let distance = loc.distance(from: hotspotLoc)
            self.distanceMeters = distance
            self.proximityLevel = max(0, min(1, 1 - (distance - 10) / 190))
            self.updateHapticRate()
        }
    }

    // Updates heading alignment score whenever the device heading changes.
    // The Reveal Lens totem doubles the acceptance window from ±45° to ±90°.
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
            let diff = abs(newHeading.magneticHeading - bearing)
            let normalised = min(diff, 360 - diff)
            let window = 45.0 + InventoryViewModel.shared.effects.alignmentWindowBonus
            self.headingAlignment = max(0, 1 - normalised / window)
            self.updateHapticRate()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in self.errorText = error.localizedDescription }
    }

    // Prepares the haptic engine on devices that support it
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        try? hapticEngine?.start()
    }

    // Reschedules the haptic pulse timer based on combined proximity + alignment.
    // Spirit Flash totem halves the pulse interval, giving faster feedback.
    func updateHapticRate() {
        hapticTimer?.invalidate()
        let combined = (proximityLevel + headingAlignment) / 2
        guard combined > 0.1 else { return }
        let baseInterval = max(0.15, 1.5 - combined * 1.35)
        let reduction = InventoryViewModel.shared.effects.cooldownReduction
        let interval = baseInterval * (1 - reduction)
        hapticTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.pulseHaptic()
        }
    }

    // Fires a single haptic pulse scaled to the current signal strength
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

    // Cancels and clears the haptic pulse timer
    func stopHaptics() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }
}

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

    init(hotspot: Hotspot) {
        self.hotspot = hotspot
        _vm = State(initialValue: ScannerViewModel(hotspot: hotspot))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GridPattern()
                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                .ignoresSafeArea()

            VStack(spacing: 0) {
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

                ActiveEffectsBar()

                Spacer()

                VStack(spacing: 8) {
                    Text("HEADING ALIGNMENT")
                        .font(.caption2).bold()
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)

                    CompassMeter(alignment: vm.headingAlignment, degrees: vm.headingDegrees)
                        .frame(height: 60)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 8) {
                    Text("PROXIMITY SIGNAL")
                        .font(.caption2).bold()
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)

                    ProximityMeter(level: vm.proximityLevel)
                        .frame(height: 24)
                        .padding(.horizontal)
                }

                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<8) { i in
                        let combined = (vm.proximityLevel + vm.headingAlignment) / 2
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Double(i) / 8.0 < combined ? Color.green : Color.white.opacity(0.1))
                            .frame(width: 20, height: Double(i + 1) * 4 + 8)
                    }
                }
                .padding()

                Spacer()

                Button {
                    showContainment = true
                } label: {
                    Text("BEGIN CONTAINMENT")
                        .font(.headline).bold()
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            vm.proximityLevel > containmentThreshold
                                ? Color.purple
                                : Color.gray.opacity(0.3)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(vm.proximityLevel <= containmentThreshold)
                .padding()

                if vm.proximityLevel <= containmentThreshold {
                    Text("Get closer to begin containment")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 8)
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
        .onDisappear { vm.stop() }
        .fullScreenCover(isPresented: $showContainment) {
            ContainmentView(hotspot: hotspot)
        }
    }
}

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

struct CompassMeter: View {
    let alignment: Double
    let degrees: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 8)

                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(colors: [.purple.opacity(0.5), .purple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * alignment, height: 8)
                    Spacer(minLength: 0)
                }

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

struct ProximityMeter: View {
    let level: Double

    // Color shifts from red → yellow → green as signal strengthens
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

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(colors: [meterColor.opacity(0.6), meterColor],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * level)
                    .animation(.easeInOut(duration: 0.3), value: level)
            }
        }
    }
}

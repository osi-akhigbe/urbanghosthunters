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

    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        stopHaptics()
    }

    private func bearingTo(lat: Double, lng: Double, from userLat: Double, userLng: Double) -> Double {
        let dLng = (lng - userLng) * .pi / 180
        let lat1 = userLat * .pi / 180
        let lat2 = lat * .pi / 180
        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

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

    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        try? hapticEngine?.start()
    }

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

    private var containmentThreshold: Double {
        let reduction = InventoryViewModel.shared.effects.cooldownReduction
        return max(0.15, 0.3 - reduction * 0.15)
    }

    private var combinedSignal: Double {
        (vm.proximityLevel + vm.headingAlignment) / 2
    }

    init(hotspot: Hotspot) {
        self.hotspot = hotspot
        _vm = State(initialValue: ScannerViewModel(hotspot: hotspot))
    }

    var body: some View {
        ZStack {
            KitScreenBackground()

            GhostARView(proximityLevel: vm.proximityLevel)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                KitHUDHeader(
                    module: "SCANNER",
                    title: hotspot.name,
                    subtitle: "DIFFICULTY \(hotspot.difficulty)",
                    readout: .init(
                        label: "DISTANCE",
                        value: "\(Int(vm.distanceMeters))m",
                        valueColor: Kit.Colors.signal
                    )
                )

                ActiveEffectsBar()

                Spacer()

                KitPanel {
                    VStack(spacing: 20) {
                        KitCompassMeter(alignment: vm.headingAlignment, degrees: vm.headingDegrees)
                        KitProximityMeter(level: vm.proximityLevel)
                        KitSignalBars(level: combinedSignal, label: "COMBINED SIGNAL")
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                VStack(spacing: 8) {
                    KitPrimaryButton(
                        title: "BEGIN CONTAINMENT",
                        enabled: vm.proximityLevel > containmentThreshold
                    ) {
                        showContainment = true
                    }

                    if vm.proximityLevel <= containmentThreshold {
                        Text("GET CLOSER TO BEGIN CONTAINMENT")
                            .font(Kit.Font.label())
                            .foregroundStyle(Kit.Colors.muted)
                            .tracking(Kit.Layout.labelTracking)
                    }
                }
                .padding(16)
            }

            if let error = vm.errorText {
                VStack {
                    KitBanner(style: .error, title: "SENSOR ERROR", message: error)
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .kitScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                KitGhostButton(title: "← EXIT") { dismiss() }
            }
        }
        .toolbarBackground(Kit.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onDisappear { vm.stop() }
        .fullScreenCover(isPresented: $showContainment) {
            ContainmentView(hotspot: hotspot)
        }
    }
}

private struct ActiveEffectsBar: View {
    var body: some View {
        let active = InventoryViewModel.shared.equippedTotems
        if !active.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(active) { totem in
                        KitChip(text: totem.type.displayName, icon: totem.type.icon)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 4)
        }
    }
}

// Legacy aliases kept for any external references
typealias CompassMeter = KitCompassMeter
typealias ProximityMeter = KitProximityMeter

//
//  ScannerView.swift
//  urbanghosthunters
//

import SwiftUI
import CoreLocation
import CoreHaptics

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

<<<<<<< HEAD
=======
    // MARK: - Bearing calculation
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
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
=======
    // MARK: - Location delegate
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            let hotspotLoc = CLLocation(latitude: self.hotspot.lat, longitude: self.hotspot.lng)
            let distance = loc.distance(from: hotspotLoc)
            self.distanceMeters = distance
<<<<<<< HEAD
=======
            // Proximity 0-1: full signal within 10m, zero at 200m+
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
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
<<<<<<< HEAD
=======
            // Alignment 0-1: 1 = facing hotspot directly
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
            let diff = abs(newHeading.magneticHeading - bearing)
            let normalised = min(diff, 360 - diff)
            self.headingAlignment = max(0, 1 - normalised / 45)
            self.updateHapticRate()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in self.errorText = error.localizedDescription }
    }

<<<<<<< HEAD
=======
    // MARK: - Haptics
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        try? hapticEngine?.start()
    }

    func updateHapticRate() {
        hapticTimer?.invalidate()
        let combined = (proximityLevel + headingAlignment) / 2
        guard combined > 0.1 else { return }
        let interval = max(0.15, 1.5 - combined * 1.35)
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
    init(hotspot: Hotspot) {
        self.hotspot = hotspot
        _vm = State(initialValue: ScannerViewModel(hotspot: hotspot))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

<<<<<<< HEAD
=======
            // Background grid
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
            GridPattern()
                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                .ignoresSafeArea()

            VStack(spacing: 0) {

<<<<<<< HEAD
=======
                // Top HUD
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
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

                Spacer()

<<<<<<< HEAD
=======
                // Compass meter
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
                VStack(spacing: 8) {
                    Text("HEADING ALIGNMENT")
                        .font(.caption2).bold()
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)
<<<<<<< HEAD
                    CompassMeter(alignment: vm.headingAlignment, degrees: vm.headingDegrees)
=======

                    CompassMeter(alignment: vm.headingAlignment,
                                 degrees: vm.headingDegrees)
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
                        .frame(height: 60)
                        .padding(.horizontal)
                }

                Spacer()

<<<<<<< HEAD
=======
                // Proximity meter
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
                VStack(spacing: 8) {
                    Text("PROXIMITY SIGNAL")
                        .font(.caption2).bold()
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)
<<<<<<< HEAD
=======

>>>>>>> origin/feature/APPDEV-20-containment-mechanic
                    ProximityMeter(level: vm.proximityLevel)
                        .frame(height: 24)
                        .padding(.horizontal)
                }

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
                        let combined = (vm.proximityLevel + vm.headingAlignment) / 2
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Double(i) / 8.0 < combined ? Color.green : Color.white.opacity(0.1))
                            .frame(width: 20, height: Double(i + 1) * 4 + 8)
                    }
                }
                .padding()

                Spacer()

<<<<<<< HEAD
=======
                // Contain button
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
                Button {
                    showContainment = true
                } label: {
                    Text("BEGIN CONTAINMENT")
                        .font(.headline).bold()
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
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
                                ? Color.purple
                                : Color.gray.opacity(0.3)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(vm.proximityLevel <= 0.3)
                .padding()

                if vm.proximityLevel <= 0.3 {
                    Text("Get closer to begin containment")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 8)
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
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
=======
        .onDisappear { vm.stop() }
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
        .fullScreenCover(isPresented: $showContainment) {
            ContainmentView(hotspot: hotspot)
        }
    }
}

// MARK: - Compass Meter
struct CompassMeter: View {
    let alignment: Double
    let degrees: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
<<<<<<< HEAD
=======
                // Track
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 8)

<<<<<<< HEAD
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.purple.opacity(0.5), .purple],
                                             startPoint: .leading, endPoint: .trailing))
=======
                // Fill
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(colors: [.purple.opacity(0.5), .purple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
                        .frame(width: geo.size.width * alignment, height: 8)
                    Spacer(minLength: 0)
                }

<<<<<<< HEAD
=======
                // Degree label
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
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
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [meterColor.opacity(0.6), meterColor],
                                         startPoint: .leading, endPoint: .trailing))
=======

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(colors: [meterColor.opacity(0.6), meterColor],
                                       startPoint: .leading, endPoint: .trailing)
                    )
>>>>>>> origin/feature/APPDEV-20-containment-mechanic
                    .frame(width: geo.size.width * level)
                    .animation(.easeInOut(duration: 0.3), value: level)
            }
        }
    }
}

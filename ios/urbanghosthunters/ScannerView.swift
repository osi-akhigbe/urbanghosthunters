//
//  ScannerView.swift
//  urbanghosthunters
//

import SwiftUI
import CoreLocation
import CoreHaptics
import UIKit

// MARK: - Location delegate helper
// Separate NSObject handles CLLocationManagerDelegate so ScannerViewModel
// stays a plain @Observable class — avoids nonisolated + Task @MainActor
// observation tracking issues that prevented meters from updating.
private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var onLocation: ((CLLocation) -> Void)?
    var onHeading: ((CLHeading) -> Void)?
    var onError: ((Error) -> Void)?

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        onLocation?(loc)
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateHeading newHeading: CLHeading) {
        onHeading?(newHeading)
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        onError?(error)
    }
}

// MARK: - ViewModel
@Observable
@MainActor
final class ScannerViewModel {
    var headingAlignment: Double = 0
    var proximityLevel: Double = 0
    var headingDegrees: Double = 0
    var distanceMeters: Double = 0
    var errorText: String?

    private let locationManager = CLLocationManager()
    private let locationDelegate = LocationDelegate()
    private var hapticEngine: CHHapticEngine?
    private var hapticTimer: Timer?
    private var bgObserver: Any?
    private var fgObserver: Any?
    let hotspot: Hotspot

    init(hotspot: Hotspot) {
        self.hotspot = hotspot

        // CLLocationManager fires callbacks on the main thread (thread it was
        // created on), so these closures run on the main actor safely.
        locationDelegate.onLocation = { [weak self] loc in
            guard let self else { return }
            let hotspotLoc = CLLocation(latitude: self.hotspot.lat, longitude: self.hotspot.lng)
            let distance = loc.distance(from: hotspotLoc)
            self.distanceMeters = distance
            self.proximityLevel = max(0, min(1, 1 - (distance - 10) / 190))
            self.updateHapticRate()
            if distance > 100 {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                self.locationManager.distanceFilter = 10
            } else {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
                self.locationManager.distanceFilter = 2
            }
        }

        locationDelegate.onHeading = { [weak self] heading in
            guard let self else { return }
            self.headingDegrees = heading.magneticHeading
            let bearing = self.bearingTo(
                lat: self.hotspot.lat,
                lng: self.hotspot.lng,
                from: self.locationManager.location?.coordinate.latitude ?? 0,
                userLng: self.locationManager.location?.coordinate.longitude ?? 0
            )
            let diff = abs(heading.magneticHeading - bearing)
            let normalised = min(diff, 360 - diff)
            self.headingAlignment = max(0, 1 - normalised / 45)
            self.updateHapticRate()
        }

        locationDelegate.onError = { [weak self] error in
            self?.errorText = error.localizedDescription
        }

        locationManager.delegate = locationDelegate
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 5
        locationManager.headingFilter = 3
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        prepareHaptics()

        bgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.pauseSensors() }

        fgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.resumeSensors() }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        stopHaptics()
        if let o = bgObserver { NotificationCenter.default.removeObserver(o) }
        if let o = fgObserver { NotificationCenter.default.removeObserver(o) }
    }

    func pauseSensors() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        stopHaptics()
    }

    func resumeSensors() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
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
    @State private var micLure = MicLureManager()
    @State private var showContainment = false
    @State private var audioStatic = AudioStaticManager()
    @State private var showCoop = false
    @State private var flashlight = FlashlightManager.shared
    @State private var ambient = AmbientLightMonitor.shared
    @Environment(\.dismiss) private var dismiss

    private var containmentThreshold: Double {
        let reduction = InventoryViewModel.shared.effects.cooldownReduction
        return max(0.15, 0.3 - reduction * 0.15)
    }

    private var canBeginContainment: Bool {
        vm.proximityLevel >= containmentThreshold || micLure.revealLevel >= 0.55
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

            ProximityGhostView(proximityLevel: vm.proximityLevel)
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
                    KitMeterBar(label: "GHOST REVEAL", level: micLure.revealLevel, tint: Kit.Colors.signal)
                    Text("Hold to lure — louder = faster reveal")
                        .font(Kit.Font.label())
                        .foregroundStyle(Kit.Colors.muted)
                    MicLureButton(micLure: micLure)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Button {
                    showCoop = true
                } label: {
                    Label("CO-OP RITUAL", systemImage: "person.2.fill")
                        .font(Kit.Font.label())
                        .foregroundStyle(Kit.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Kit.Colors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                NearbyAgentsView()
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                VStack(spacing: 8) {
                    KitPrimaryButton(
                        title: "BEGIN CONTAINMENT",
                        enabled: canBeginContainment
                    ) {
                        showContainment = true
                    }

                    if !canBeginContainment {
                        Text("GET CLOSER TO BEGIN CONTAINMENT")
                            .font(Kit.Font.label())
                            .foregroundStyle(Kit.Colors.muted)
                            .tracking(Kit.Layout.labelTracking)

                        Button("Demo: start containment anyway") {
                            showContainment = true
                        }
                        .font(.caption)
                        .foregroundStyle(Kit.Colors.accent)
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
        .fullScreenCover(isPresented: $showCoop) {
            CoopRitualView(hotspot: hotspot)
        }
        .fullScreenCover(isPresented: $showContainment) {
            ContainmentView(hotspot: hotspot)
        }
        .kitScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                KitGhostButton(title: "← EXIT") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                FlashlightButton(manager: flashlight, isLowLight: ambient.isLowLight)
            }
        }
        .onAppear {
            micLure.prepare()
            audioStatic.prepare()
            ambient.start()
        }
        .onChange(of: vm.proximityLevel) { _, newValue in
            audioStatic.setProximity(newValue)
        }
        .onDisappear {
            vm.stop()
            micLure.stop()
            audioStatic.stop()
            ambient.stop()
            flashlight.turnOff()
        }
    }
}

private struct MicLureButton: View {
    let micLure: MicLureManager
    @State private var isHolding = false

    var body: some View {
        Label(isHolding ? "LURING…" : "HOLD TO LURE", systemImage: "mic.fill")
            .font(Kit.Font.module())
            .tracking(1)
            .foregroundStyle(isHolding ? Kit.Colors.background : Kit.Colors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isHolding ? Kit.Colors.accent : Kit.Colors.accent.opacity(0.12),
                in: RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
                    .stroke(Kit.Colors.accent.opacity(0.5), lineWidth: 1)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHolding {
                            isHolding = true
                            micLure.beginLure()
                        }
                    }
                    .onEnded { _ in
                        isHolding = false
                        micLure.endLure()
                    }
            )
    }
}

// MARK: - Pure SwiftUI ghost overlay (no ARView — avoids Metal conflict with ContainmentView camera)

private struct ProximityGhostView: View {
    let proximityLevel: Double

    var body: some View {
        TimelineView(.animation) { tl in
            GhostFrame(
                phase: tl.date.timeIntervalSinceReferenceDate,
                proximity: proximityLevel
            )
        }
    }
}

private struct GhostFrame: View {
    let phase: Double
    let proximity: Double

    var body: some View {
        let yFloat = sin(phase * 1.6) * 18.0
        let s     = 0.45 + proximity * 0.65
        let a     = proximity * 0.68
        let c     = Color(red: 0.80, green: 0.96, blue: 1.0)

        ZStack {
            // Outer glow
            Circle()
                .fill(c.opacity(a * 0.25))
                .frame(width: 220, height: 220)
                .blur(radius: 45)

            // Body
            Ellipse()
                .fill(c.opacity(a))
                .frame(width: 88, height: 118)
                .blur(radius: 12)

            // Head
            Circle()
                .fill(c.opacity(a))
                .frame(width: 78, height: 78)
                .offset(y: -88)
                .blur(radius: 10)

            // Eyes
            HStack(spacing: 22) {
                Circle()
                    .fill(Color(red: 0.06, green: 0.02, blue: 0.18).opacity(min(1, a * 1.5)))
                    .frame(width: 11, height: 11)
                Circle()
                    .fill(Color(red: 0.06, green: 0.02, blue: 0.18).opacity(min(1, a * 1.5)))
                    .frame(width: 11, height: 11)
            }
            .offset(y: -90)

            // Tail wisps
            HStack(spacing: 7) {
                Circle().fill(c.opacity(a * 0.75)).frame(width: 30, height: 30).blur(radius: 8)
                Circle().fill(c.opacity(a * 0.75)).frame(width: 35, height: 35).blur(radius: 8)
                Circle().fill(c.opacity(a * 0.75)).frame(width: 30, height: 30).blur(radius: 8)
            }
            .offset(y: 70)
        }
        .scaleEffect(s)
        .offset(y: yFloat)
    }
}

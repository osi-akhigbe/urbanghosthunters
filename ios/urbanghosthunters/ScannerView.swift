//
//  ScannerView.swift
//  urbanghosthunters
//

import SwiftUI
import CoreLocation
import CoreHaptics
import UIKit

// MARK: - ViewModel
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
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 5
        locationManager.headingFilter = 3
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        prepareHaptics()

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pauseSensors()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resumeSensors()
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        stopHaptics()
        NotificationCenter.default.removeObserver(self)
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

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            let hotspotLoc = CLLocation(latitude: self.hotspot.lat, longitude: self.hotspot.lng)
            let distance = loc.distance(from: hotspotLoc)
            self.distanceMeters = distance
            self.proximityLevel = max(0, min(1, 1 - (distance - 10) / 190))
            self.updateHapticRate()

            if distance > 100 {
                manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                manager.distanceFilter = 10
            } else {
                manager.desiredAccuracy = kCLLocationAccuracyBest
                manager.distanceFilter = 2
            }
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
            self.headingAlignment = max(0, 1 - normalised / 45)
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
        }
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

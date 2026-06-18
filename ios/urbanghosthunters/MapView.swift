//
//  MapView.swift
//  urbanghosthunters
//

import SwiftUI
import MapKit
import Observation
import Supabase

struct Hotspot: Identifiable, Decodable {
    let id: UUID
    let name: String
    let lat: Double
    let lng: Double
    let radius_m: Int
    let difficulty: Int
    let active: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

@Observable
@MainActor
final class MapViewModel: NSObject, CLLocationManagerDelegate {
    var hotspots: [Hotspot] = []
    var userLocation: CLLocationCoordinate2D?
    var nearestHotspot: Hotspot?
    var errorText: String?
    var isLoading = false

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func fetchHotspots() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result: [Hotspot] = try await SupabaseManager.shared.client
                .from("hotspots")
                .select()
                .eq("active", value: true)
                .execute()
                .value
            hotspots = result
            updateNearest()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func updateNearest() {
        guard let userLocation else { return }
        let userCL = CLLocation(latitude: userLocation.latitude,
                                longitude: userLocation.longitude)
        nearestHotspot = hotspots.min(by: { a, b in
            let distA = CLLocation(latitude: a.lat, longitude: a.lng).distance(from: userCL)
            let distB = CLLocation(latitude: b.lat, longitude: b.lng).distance(from: userCL)
            return distA < distB
        })
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.userLocation = loc.coordinate
            self.updateNearest()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in
            self.errorText = error.localizedDescription
        }
    }
}

struct MapView: View {
    @State private var vm = MapViewModel()
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                UserAnnotation()

                ForEach(vm.hotspots) { hotspot in
                    Annotation(hotspot.name, coordinate: hotspot.coordinate) {
                        Image(systemName: "rays")
                            .foregroundStyle(Kit.Colors.accent)
                            .padding(8)
                            .background(Kit.Colors.background.opacity(0.85), in: Circle())
                            .overlay(Circle().stroke(Kit.Colors.accent.opacity(0.5), lineWidth: 1))
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea()

            if vm.isLoading {
                VStack {
                    KitLoadingView(message: "SCANNING SECTOR…")
                        .padding(.top, 60)
                    Spacer()
                }
            }

            if let nearest = vm.nearestHotspot {
                NearestAnomalySheet(hotspot: nearest)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            if let error = vm.errorText {
                VStack {
                    Spacer()
                    KitBanner(style: .error, title: "MAP ERROR", message: error)
                        .padding(.bottom, vm.nearestHotspot == nil ? 32 : 120)
                }
            }
        }
        .task {
            await vm.fetchHotspots()
        }
    }
}

struct NearestAnomalySheet: View {
    let hotspot: Hotspot

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(Kit.Colors.signal)
                .frame(width: 44, height: 44)
                .background(Kit.Colors.signal.opacity(0.12), in: RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius))

            VStack(alignment: .leading, spacing: 4) {
                Text("NEAREST ANOMALY")
                    .font(Kit.Font.label())
                    .foregroundStyle(Kit.Colors.label)
                    .tracking(Kit.Layout.labelTracking)

                Text(hotspot.name)
                    .font(Kit.Font.title())
                    .foregroundStyle(.white)

                Text("DIFF \(hotspot.difficulty) · \(hotspot.radius_m)M RADIUS")
                    .font(Kit.Font.label())
                    .foregroundStyle(Kit.Colors.muted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Kit.Colors.muted)
        }
        .padding(Kit.Layout.panelPadding)
        .background(Kit.Colors.panel, in: RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
                .stroke(Kit.Colors.panelBorder, lineWidth: 1)
        )
    }
}

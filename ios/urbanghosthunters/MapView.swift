//
//  MapView.swift
//  urbanghosthunters
//

import SwiftUI
import MapKit
import Observation
import Supabase

// MARK: - Hotspot model
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

// MARK: - ViewModel
@Observable
@MainActor
final class MapViewModel: NSObject, CLLocationManagerDelegate {
    var hotspots: [Hotspot] = []
    var userLocation: CLLocationCoordinate2D?
    var nearestHotspot: Hotspot?
    var errorText: String?

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func fetchHotspots() async {
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

// MARK: - Map View
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
                            .foregroundStyle(.purple)
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea()

            if let nearest = vm.nearestHotspot {
                NearestAnomalySheet(hotspot: nearest)
                    .padding()
            }

            if let error = vm.errorText {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 120)
            }
        }
        .task {
            await vm.fetchHotspots()
        }
    }
}

// MARK: - Bottom sheet
struct NearestAnomalySheet: View {
    let hotspot: Hotspot

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(.purple)

            VStack(alignment: .leading, spacing: 2) {
                Text("Nearest Anomaly")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(hotspot.name)
                    .font(.headline)
                Text("Difficulty \(hotspot.difficulty) · \(hotspot.radius_m)m radius")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

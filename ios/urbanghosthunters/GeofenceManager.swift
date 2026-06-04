import Combine
import Foundation
import CoreLocation
import UserNotifications
import Supabase

@MainActor
final class GeofenceManager: NSObject, ObservableObject {

    static let shared = GeofenceManager()

    @Published var nearbyHotspot: Hotspot?
    @Published var directionLabel: String = ""
    @Published var distanceMeters: Int = 0

    @Published private(set) var hotspots: [Hotspot] = []

    private let clManager = CLLocationManager()

    private override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBest
        clManager.distanceFilter = 5
    }

    func loadHotspots() async {
        do {
            let result: [Hotspot] = try await SupabaseManager.shared.client
                .from("hotspots")
                .select()
                .eq("active", value: true)
                .execute()
                .value
            hotspots = result
            registerRegions()
        } catch {
            print("[GeofenceManager] Failed to load hotspots: \(error.localizedDescription)")
        }
    }

    func start() {
        requestNotificationPermission()
        clManager.requestWhenInUseAuthorization()
        if hotspots.isEmpty {
            registerRegions()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func registerRegions() {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }

        for region in clManager.monitoredRegions {
            clManager.stopMonitoring(for: region)
        }

        for hotspot in hotspots {
            let region = CLCircularRegion(
                center: hotspot.coordinate,
                radius: CLLocationDistance(min(hotspot.radius_m, 400)),
                identifier: hotspot.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            clManager.startMonitoring(for: region)
        }
    }

    private func checkProximity(to userLocation: CLLocation) {
        for hotspot in hotspots {
            let hotspotLocation = CLLocation(
                latitude: hotspot.coordinate.latitude,
                longitude: hotspot.coordinate.longitude
            )
            let distance = userLocation.distance(from: hotspotLocation)

            if distance <= Double(hotspot.radius_m) {
                if nearbyHotspot?.id != hotspot.id {
                    nearbyHotspot = hotspot
                    distanceMeters = Int(distance)
                    directionLabel = cardinalDirection(from: userLocation, to: hotspot.coordinate)
                    sendLocalNotification(hotspot: hotspot, distance: Int(distance), direction: directionLabel)
                }
                return
            }
        }
        nearbyHotspot = nil
    }

    private func sendLocalNotification(hotspot: Hotspot, distance: Int, direction: String) {
        let content = UNMutableNotificationContent()
        content.title = "Anomaly Detected"
        content.body = "You're \(distance)m \(direction) of \(hotspot.name)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: hotspot.id.uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func cardinalDirection(from userLoc: CLLocation, to target: CLLocationCoordinate2D) -> String {
        let lat1 = userLoc.coordinate.latitude * .pi / 180
        let lat2 = target.latitude * .pi / 180
        let dLon = (target.longitude - userLoc.coordinate.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearingDeg = atan2(y, x) * 180 / .pi
        let normalized = (bearingDeg + 360).truncatingRemainder(dividingBy: 360)

        switch normalized {
        case 315..<360, 0..<45: return "North"
        case 45..<135: return "East"
        case 135..<225: return "South"
        default: return "West"
        }
    }
}

extension GeofenceManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        checkProximity(to: latest)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let hotspot = hotspots.first(where: { $0.id.uuidString == region.identifier }) {
            nearbyHotspot = hotspot
            directionLabel = ""
            distanceMeters = 0
            sendLocalNotification(hotspot: hotspot, distance: 0, direction: "nearby")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[GeofenceManager] Location error: \(error.localizedDescription)")
    }
}

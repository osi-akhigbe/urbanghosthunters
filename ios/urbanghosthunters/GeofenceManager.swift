import Foundation
import CoreLocation       // For CLLocationManager, CLLocation, CLRegion
import UserNotifications  // For local push notifications

// MARK: - Hotspot model
// Represents a named paranormal location the user can approach
struct Hotspot: Identifiable {
    let id = UUID()                            // Unique ID so SwiftUI can iterate
    let name: String                           // Display name shown in the banner
    let coordinate: CLLocationCoordinate2D    // Lat/lon of the hotspot
    let radiusMeters: Double                  // How close (in meters) to trigger an alert
}

// MARK: - GeofenceManager
// Owns the CLLocationManager, checks proximity on every location update,
// fires a local notification, and publishes `nearbyHotspot` for the UI.
@MainActor
final class GeofenceManager: NSObject, ObservableObject {

    // Singleton — one manager for the whole app
    static let shared = GeofenceManager()

    // MARK: Published state
    // The UI observes this; non-nil means "show the banner"
    @Published var nearbyHotspot: Hotspot?
    // Direction string shown in the banner, e.g. "North", "East"
    @Published var directionLabel: String = ""
    // Distance in metres to the nearby hotspot
    @Published var distanceMeters: Int = 0

    // MARK: Private internals
    private let clManager = CLLocationManager()  // The system location manager

    // Seeded test hotspots – replace/extend with Supabase data later
    // To test: put one coordinate near your actual current GPS location
    let hotspots: [Hotspot] = [
        Hotspot(
            name: "Old Town Haunt",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 50
        ),
        Hotspot(
            name: "Haunted Bridge",
            coordinate: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2712),
            radiusMeters: 50
        )
    ]

    // MARK: Init
    private override init() {
        super.init()
        clManager.delegate = self              // Receive callbacks on this object
        clManager.desiredAccuracy = kCLLocationAccuracyBest  // Highest GPS accuracy
        clManager.distanceFilter = 5           // Only fire didUpdateLocations every 5 m moved
    }

    // MARK: Public API

    // Call this once (e.g. from .onAppear) to ask for permission and start GPS
    func start() {
        requestNotificationPermission()         // Ask for notification permission up front
        clManager.requestWhenInUseAuthorization() // Ask for "while using app" location
        // startUpdatingLocation is called in the delegate once permission is granted
        registerRegions()                       // Set up optional system-level geofence regions
    }

    // MARK: - Private helpers

    // Asks the system for notification permission (needed for local alerts)
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // Registers CLCircularRegion for each hotspot so iOS can wake the app
    // even when it's backgrounded (region monitoring is hardware-accelerated)
    private func registerRegions() {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }

        // Remove any old regions first to avoid duplicates
        for region in clManager.monitoredRegions {
            clManager.stopMonitoring(for: region)
        }

        for hotspot in hotspots {
            let region = CLCircularRegion(
                center: hotspot.coordinate,
                radius: hotspot.radiusMeters,
                identifier: hotspot.id.uuidString  // Unique ID ties back to our Hotspot
            )
            region.notifyOnEntry = true   // Fire when user walks in
            region.notifyOnExit  = false  // We don't care about walking away here
            clManager.startMonitoring(for: region)
        }
    }

    // Called on every GPS update — checks distance to every hotspot
    private func checkProximity(to userLocation: CLLocation) {
        for hotspot in hotspots {
            let hotspotLocation = CLLocation(
                latitude:  hotspot.coordinate.latitude,
                longitude: hotspot.coordinate.longitude
            )
            let distance = userLocation.distance(from: hotspotLocation) // Returns metres (Double)

            if distance <= hotspot.radiusMeters {
                // Only fire the alert once per entry (guard against repeated triggers)
                if nearbyHotspot?.id != hotspot.id {
                    nearbyHotspot  = hotspot
                    distanceMeters = Int(distance)
                    directionLabel = cardinalDirection(from: userLocation, to: hotspot.coordinate)
                    sendLocalNotification(hotspot: hotspot, distance: Int(distance), direction: directionLabel)
                }
                return  // Stop at the first match — one alert at a time
            }
        }
        // User is not near any hotspot — clear the banner
        nearbyHotspot = nil
    }

    // Fires a local notification that shows up in the notification centre
    private func sendLocalNotification(hotspot: Hotspot, distance: Int, direction: String) {
        let content = UNMutableNotificationContent()
        content.title = "Anomaly Detected"                                   // Bold notification title
        content.body  = "You're \(distance)m \(direction) of \(hotspot.name)" // e.g. "48m North of Old Town Haunt"
        content.sound = .default                                             // Play the default alert sound

        // nil trigger = deliver immediately
        let request = UNNotificationRequest(
            identifier: hotspot.id.uuidString,  // Using the hotspot ID de-dupes repeat notifications
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // Returns a cardinal direction string ("North", "East", "South", "West")
    // by computing the bearing from the user's location to the hotspot
    private func cardinalDirection(from userLoc: CLLocation, to target: CLLocationCoordinate2D) -> String {
        let lat1 = userLoc.coordinate.latitude  * .pi / 180  // Convert degrees → radians
        let lat2 = target.latitude              * .pi / 180
        let dLon = (target.longitude - userLoc.coordinate.longitude) * .pi / 180

        // Standard bearing formula
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearingDeg = atan2(y, x) * 180 / .pi              // −180…180
        let normalized = (bearingDeg + 360).truncatingRemainder(dividingBy: 360) // 0…360

        switch normalized {
        case 315..<360, 0..<45:  return "North"
        case 45..<135:           return "East"
        case 135..<225:          return "South"
        default:                 return "West"
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension GeofenceManager: CLLocationManagerDelegate {

    // Called each time the GPS fires a new location fix
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }  // Grab the most recent fix
        checkProximity(to: latest)                          // Run our proximity check
    }

    // Called when the user grants or denies location access
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()  // Permission granted — start GPS
        default:
            break  // Denied or restricted — do nothing
        }
    }

    // Called by region monitoring when the user enters a registered CLCircularRegion
    // This fires even if the app is backgrounded (iOS wakes it briefly)
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // Match the region back to one of our Hotspot objects by ID
        if let hotspot = hotspots.first(where: { $0.id.uuidString == region.identifier }) {
            nearbyHotspot  = hotspot
            directionLabel = ""   // No user location available in background, skip direction
            distanceMeters = 0
            sendLocalNotification(hotspot: hotspot, distance: 0, direction: "nearby")
        }
    }

    // Log any location errors (GPS unavailable, simulator, etc.)
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[GeofenceManager] Location error: \(error.localizedDescription)")
    }
}

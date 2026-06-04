import SwiftUI

struct MainAppView: View {
    @StateObject private var supa     = SupabaseManager.shared
    @StateObject private var geofence = GeofenceManager.shared

    @State private var bannerDismissed = false

    var body: some View {
        ZStack(alignment: .top) {

            // MARK: Main content
            TabView {
                MapView()
                    .tabItem {
                        Label("Map", systemImage: "map.fill")
                    }

                Text("Journal")
                    .tabItem {
                        Label("Journal", systemImage: "book.fill")
                    }

                InventoryView()
                    .tabItem {
                        Label("Inventory", systemImage: "bag.fill")
                    }
            }

            // MARK: Anomaly banner
            if let hotspot = geofence.nearbyHotspot, !bannerDismissed {
                AnomalyBannerView(
                    hotspot:   hotspot,
                    distance:  geofence.distanceMeters,
                    direction: geofence.directionLabel,
                    onDismiss: {
                        withAnimation {
                            bannerDismissed = true
                        }
                    }
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: geofence.nearbyHotspot?.id)
            }
        }
        .onAppear {
            geofence.start()
        }
        .onChange(of: geofence.nearbyHotspot?.id) { _ in
            bannerDismissed = false
        }
    }
}
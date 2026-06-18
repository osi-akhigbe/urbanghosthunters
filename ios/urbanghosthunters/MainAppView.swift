import SwiftUI
import Supabase

struct MainAppView: View {
    @StateObject private var geofence = GeofenceManager.shared
    @State private var bannerDismissed = false

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                NavigationStack {
                    MapView()
                }
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }

                NavigationStack {
                    JournalView()
                }
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }

                NavigationStack {
                    TotemLoadoutView()
                }
                .tabItem {
                    Label("Loadout", systemImage: "shield.fill")
                }
            }

            if let hotspot = geofence.nearbyHotspot, !bannerDismissed {
                AnomalyBannerView(
                    hotspot: hotspot,
                    distance: geofence.distanceMeters,
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
        .task {
            await geofence.loadHotspots()
            geofence.start()
            await PlayerInventory.shared.load()
        }
        .onChange(of: geofence.nearbyHotspot?.id) { _, _ in
            bannerDismissed = false
        }
    }
}

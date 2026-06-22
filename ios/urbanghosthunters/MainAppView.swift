import SwiftUI
import Supabase

struct MainAppView: View {
    @StateObject private var geofence = GeofenceManager.shared
    @State private var bannerDismissed = false
    @State private var showGhostPreview = false

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

                InventoryView()
                    .tabItem {
                        Label("Inventory", systemImage: "bag.fill")
                    }
            }
            .tint(Kit.Colors.accent)

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
        .kitScreen()
        .overlay(alignment: .bottomTrailing) {
            // DEBUG — remove before shipping
            Button {
                showGhostPreview = true
            } label: {
                Image(systemName: "eye.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Kit.Colors.accent)
                    .padding(20)
            }
        }
        .fullScreenCover(isPresented: $showGhostPreview) {
            GhostPreviewView()
        }
        .task {
            geofence.start()
            await geofence.loadHotspots()
            await InventoryViewModel.shared.fetch()
        }
        .onChange(of: geofence.nearbyHotspot?.id) { _, _ in
            bannerDismissed = false
        }
    }
}

private struct JournalPlaceholderView: View {
    var body: some View {
        ZStack {
            KitScreenBackground()
            KitEmptyState(
                icon: "book.closed",
                title: "JOURNAL OFFLINE",
                message: "Encounter logs will appear here after your first hunt."
            )
        }
        .kitScreen()
    }
}

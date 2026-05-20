import SwiftUI

struct MainAppView: View {
    @StateObject private var supa     = SupabaseManager.shared   // Auth state
    @StateObject private var geofence = GeofenceManager.shared   // Location + proximity manager

    // Controls whether the banner is visible (set false by the dismiss button)
    @State private var bannerDismissed = false

    var body: some View {
        ZStack(alignment: .top) {  // ZStack so the banner floats above all other content

            // MARK: Main content
            VStack(spacing: 12) {
                Image(systemName: "smoke.fill")
                    .imageScale(.large)
                    .foregroundStyle(.tint)

                Text("Signed in")
                    .font(.title3)
                    .bold()

                if let uid = supa.userId {
                    Text(uid)
                        .font(.footnote)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()

            // MARK: Anomaly banner
            // Show the banner if we're near a hotspot AND the user hasn't dismissed it
            if let hotspot = geofence.nearbyHotspot, !bannerDismissed {
                AnomalyBannerView(
                    hotspot:   hotspot,
                    distance:  geofence.distanceMeters,
                    direction: geofence.directionLabel,
                    onDismiss: {
                        withAnimation {
                            bannerDismissed = true  // Slide the banner away
                        }
                    }
                )
                // Animate the banner in/out smoothly
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: geofence.nearbyHotspot?.id)
            }
        }
        // Start location services as soon as this view appears
        .onAppear {
            geofence.start()
        }
        // Reset dismissed flag when the user leaves and re-enters a hotspot zone
        .onChange(of: geofence.nearbyHotspot?.id) { _ in
            bannerDismissed = false  // New hotspot = fresh alert
        }
    }
}

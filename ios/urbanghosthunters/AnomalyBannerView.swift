import SwiftUI

// MARK: - AnomalyBannerView
// A dismissible banner that slides down from the top of the screen
// when the user walks within range of a hotspot.
struct AnomalyBannerView: View {

    let hotspot: Hotspot    // The hotspot that triggered this banner
    let distance: Int       // Distance in metres from user to hotspot
    let direction: String   // Cardinal direction, e.g. "North"

    // Called when the user taps the X to dismiss the banner
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {

            // Ghost icon — themed for the app
            Image(systemName: "figure.walk.motion")
                .font(.title2)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                // Bold title line
                Text("Anomaly Detected")
                    .font(.headline)
                    .foregroundColor(.white)

                // Details line — "48m North · Old Town Haunt"
                Text("\(distance)m \(direction) · \(hotspot.name)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }

            Spacer() // Push dismiss button to the right

            // Dismiss button — lets the user clear the banner manually
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.title3)
            }
        }
        .padding(.horizontal, 16)  // Side padding inside the banner
        .padding(.vertical, 14)    // Top/bottom padding
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.9))   // Spooky purple theme
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)  // Margin from screen edges
        .padding(.top, 8)          // Small gap from the safe-area top
        // Slide in from above when it appears
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Preview
#Preview {
    ZStack(alignment: .top) {
        Color.black.ignoresSafeArea()
        AnomalyBannerView(
            hotspot: Hotspot(id: UUID(), name: "Old Town Haunt", lat: 37.7749, lng: -122.4194, radius_m: 50, difficulty: 1, active: true),
            distance: 48,
            direction: "North",
            onDismiss: {}
        )
    }
}

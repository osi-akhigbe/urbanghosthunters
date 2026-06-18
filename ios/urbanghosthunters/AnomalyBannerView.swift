import SwiftUI

struct AnomalyBannerView: View {
    let hotspot: Hotspot
    let distance: Int
    let direction: String
    var onDismiss: () -> Void

    private var detail: String {
        if direction.isEmpty {
            return hotspot.name
        }
        return "\(distance)M \(direction.uppercased()) · \(hotspot.name)"
    }

    var body: some View {
        KitBanner(
            style: .alert,
            title: "ANOMALY DETECTED",
            message: detail,
            onDismiss: onDismiss
        )
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    ZStack(alignment: .top) {
        KitScreenBackground()
        AnomalyBannerView(
            hotspot: Hotspot(id: UUID(), name: "Old Town Haunt", lat: 37.7749, lng: -122.4194, radius_m: 50, difficulty: 1, active: true),
            distance: 48,
            direction: "North",
            onDismiss: {}
        )
    }
}

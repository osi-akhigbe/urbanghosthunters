import SwiftUI

struct MainAppView: View {
    @StateObject private var supa = SupabaseManager.shared

    var body: some View {
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
    }
}


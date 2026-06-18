import SwiftUI
import Supabase

struct MainAppView: View {
    var body: some View {
        TabView {
            NavigationStack {
                MapView()
            }
            .tabItem {
                Label("Map", systemImage: "map.fill")
            }

            Text("Journal")
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
        }
    }
}
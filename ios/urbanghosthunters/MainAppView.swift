import SwiftUI

struct MainAppView: View {
    var body: some View {
        TabView {
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }

            Text("Journal") // placeholder for Sprint 2
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
        }
    }
}
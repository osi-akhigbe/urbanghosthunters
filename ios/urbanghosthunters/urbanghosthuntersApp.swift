//
//  urbanghosthuntersApp.swift
//  urbanghosthunters
//

import SwiftUI
import Supabase

@main
struct urbanghosthuntersApp: App {
    init() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(red: 0.012, green: 0.0, blue: 0.118, alpha: 1)
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(red: 0.012, green: 0.0, blue: 0.118, alpha: 1)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Kit.Colors.accent)
                .onOpenURL { url in
                    Task {
                        try? await SupabaseManager.shared.client.auth.session(from: url)
                    }
                }
        }
    }
}

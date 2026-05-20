//
//  urbanghosthuntersApp.swift
//  urbanghosthunters
//
//  Created by Jarvis Akhigbe on 09/05/2026.
//

import SwiftUI
import Supabase

@main
struct urbanghosthuntersApp: App {
    init() {
        Task { @MainActor in
            await PermissionsManager.shared.requestAll()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Task {
                        try? await SupabaseManager.shared.client.auth.session(from: url)
                    }
                }
        }
    }
}

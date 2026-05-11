//
//  ContentView.swift
//  urbanghosthunters
//
//  Created by Jarvis Akhigbe on 09/05/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var supa = SupabaseManager.shared

    var body: some View {
        if supa.userId == nil {
            AuthView()
        } else {
            MainAppView()
        }
    }
}

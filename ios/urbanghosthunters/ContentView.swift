//
//  ContentView.swift
//  urbanghosthunters
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var supa = SupabaseManager.shared

    var body: some View {
        if supa.isSignedIn {
            MainAppView()
        } else {
            AuthView()
        }
    }
}

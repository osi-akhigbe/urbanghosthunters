//
//  SpabaseManager.swift
//  urbanghosthunters
//
//  Created by Jarvis Akhigbe on 10/05/2026.
//
import Foundation
import Combine
import Supabase

enum Secrets {
    static func string(_ key: String) -> String {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
            let value = dict[key] as? String,
            !value.isEmpty
        else {
            fatalError("Missing \(key) in Secrets.plist")
        }
        return value
    }
}

@MainActor
final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let supabaseURL = URL(string: Secrets.string("SUPABASE_URL"))!
        let supabaseKey = Secrets.string("SUPABASE_ANON_KEY")
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }

    var userId: String? {
        client.auth.currentUser?.id.uuidString
    }
}

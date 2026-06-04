//
//  SupabaseManager.swift
//  urbanghosthunters
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

    @Published private(set) var isSignedIn = false

    private var authTask: Task<Void, Never>?

    private init() {

    if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist") {
    print("✅ Secrets.plist found at: \(url)")
    } else {
    print("❌ Secrets.plist NOT found in bundle")
    }


        let supabaseURL = URL(string: Secrets.string("SUPABASE_URL"))!
        let supabaseKey = Secrets.string("SUPABASE_ANON_KEY")
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)

        isSignedIn = client.auth.currentSession != nil

        authTask = Task { [weak self] in
            guard let self else { return }
            for await (_, session) in client.auth.authStateChanges {
                await MainActor.run {
                    self.isSignedIn = session != nil
                }
            }
        }
    }

    var userId: String? {
        client.auth.currentUser?.id.uuidString
    }
}

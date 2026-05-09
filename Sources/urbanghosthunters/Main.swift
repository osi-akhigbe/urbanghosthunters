// The Swift Programming Language
// https://docs.swift.org/swift-book


import Foundation
import Supabase

// 1. Define your credentials (use the ones from your Supabase dashboard)
let supabaseURL = URL(string: "https://xazlkmjxxzdgnhfhbrjn.supabase.co")!
let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhhemxrbWp4eHpkZ25oZmhicmpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzMTM0MDMsImV4cCI6MjA5Mzg4OTQwM30.10NQjugYdCziWs0K1RcJHr_qmVs4gTu7K2WdaxxB_RQ"

// 2. Initialize the client
let client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)

// 3. Create a function to test the connection
func testDatabase() async {
    print("Connecting to Supabase...")
    do {
        // Replace 'your_table' with an actual table name from your dashboard
        let response = try await client.database
        .from("test_table")
        .select()
        .execute()
        print("I found this in the database: \(response.value)")
    } catch {
        print("Connection failed: \(error)")
    }
}

// 4. Run the code
await testDatabase()

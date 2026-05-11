import Foundation
import Supabase

let supabaseURL = URL(string: "https://xazlkmjxxzdgnhfhbrjn.supabase.co")!
let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhhemxrbWp4eHpkZ25oZmhicmpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzMTM0MDMsImV4cCI6MjA5Mzg4OTQwM30.10NQjugYdCziWs0K1RcJHr_qmVs4gTu7K2WdaxxB_RQ"

let client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)

func testDatabase() async {
    print("Connecting to Supabase...")
    do {
        let response = try await client
            .from("test_table")
            .select()
            .execute()
        print("I found this in the database: \(response.value)")
    } catch {
        print("Connection failed: \(error)")
    }
}

@main
struct urbanghosthunters {
    static func main() async {
        await testDatabase()
    }
}

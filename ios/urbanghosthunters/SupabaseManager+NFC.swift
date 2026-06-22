import Foundation

extension SupabaseManager {
    func lookupNFCTag(uid: String) async throws -> NFCTagRecord? {
        let records: [NFCTagRecord] = try await client
            .from("nfc_tags")
            .select()
            .eq("uid", value: uid)
            .limit(1)
            .execute()
            .value
        return records.first
    }
}

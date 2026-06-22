import Foundation
import Supabase

struct Totem: Decodable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let bonus_type: String
}

struct UserTotemRow: Decodable, Identifiable {
    let id: UUID
    let totem_id: UUID
    let equipped: Bool
    let totems: Totem?
}

@Observable
@MainActor
final class PlayerInventory {
    static let shared = PlayerInventory()

    var ownedTotems: [UserTotemRow] = []
    var equippedTotem: Totem?
    var errorText: String?

    var sealTimeBonus: Int {
    guard equippedTotem?.bonus_type == "sealTime" else { return 0 }
    return 5
}

    var shieldBonus: Int {
        guard equippedTotem?.bonus_type == "shield" else { return 0 }
        return 15
    }

    var lureBonus: Double {
        guard equippedTotem?.bonus_type == "lure" else { return 0 }
        return 0.1
    }

    func load() async {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { return }
        errorText = nil
        do {
            ownedTotems = try await SupabaseManager.shared.client
                .from("user_totems")
                .select("id, totem_id, equipped, totems(id, name, description, bonus_type)")
                .eq("user_id", value: userId)
                .execute()
                .value
            equippedTotem = ownedTotems.first(where: { $0.equipped })?.totems
        } catch {
            errorText = error.localizedDescription
        }
    }

    func grantTotemIfNeeded(totemName: String = "Spirit Ward") async {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { return }
        do {
            let totems: [Totem] = try await SupabaseManager.shared.client
                .from("totems")
                .select()
                .eq("name", value: totemName)
                .limit(1)
                .execute()
                .value
            guard let totem = totems.first else { return }

            struct Insert: Encodable {
                let user_id: UUID
                let totem_id: UUID
                let equipped: Bool
            }
            try await SupabaseManager.shared.client
                .from("user_totems")
                .insert(Insert(user_id: userId, totem_id: totem.id, equipped: false))
                .execute()
        } catch {
            // ignore duplicate
        }
        await load()
    }

    func equip(totemId: UUID) async {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { return }
        do {
            struct Patch: Encodable { let equipped: Bool }
            for row in ownedTotems {
                try await SupabaseManager.shared.client
                    .from("user_totems")
                    .update(Patch(equipped: row.totem_id == totemId))
                    .eq("user_id", value: userId)
                    .eq("totem_id", value: row.totem_id)
                    .execute()
            }
        } catch {
            errorText = error.localizedDescription
        }
        await load()
    }
}

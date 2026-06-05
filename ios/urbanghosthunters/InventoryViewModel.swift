import Foundation
import Observation

@Observable
@MainActor
final class InventoryViewModel {
    static let shared = InventoryViewModel()

    var totems: [Totem] = []
    var isLoading = false
    var errorText: String?

    // All totems the user currently has equipped
    var equippedTotems: [Totem] {
        totems.filter { $0.equipped }
    }

    // Computes the combined gameplay bonuses from all equipped totems
    var effects: TotemEffects {
        let types = Set(equippedTotems.map { $0.type })
        return TotemEffects(
            sealTimeBonus:        types.contains(.sealStability) ? 5 : 0,
            alignmentWindowBonus: types.contains(.revealWindow)  ? 45 : 0,
            cooldownReduction:    types.contains(.flashCooldown) ? 0.5 : 0
        )
    }

    // Loads totems from Supabase; seeds starter totems if the user has none
    func fetch() async {
        isLoading = true
        defer { isLoading = false }
        do {
            totems = try await SupabaseManager.shared.client
                .from("totems")
                .select()
                .execute()
                .value
            if totems.isEmpty { await seedStarterTotems() }
        } catch {
            errorText = error.localizedDescription
        }
    }

    // Flips a totem's equipped state locally and syncs the change to Supabase.
    // Rolls back the local change if the Supabase update fails.
    func toggleEquip(_ totem: Totem) async {
        guard let index = totems.firstIndex(where: { $0.id == totem.id }) else { return }
        let newValue = !totem.equipped
        totems[index].equipped = newValue
        do {
            try await SupabaseManager.shared.client
                .from("totems")
                .update(["equipped": newValue])
                .eq("id", value: totem.id.uuidString)
                .execute()
        } catch {
            totems[index].equipped = !newValue
            errorText = error.localizedDescription
        }
    }

    // Inserts one totem of each type for a new user so they have something to equip
    private func seedStarterTotems() async {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { return }
        let starters = TotemType.allCases.map { type in
            [
                "user_id":     userId.uuidString,
                "type":        type.rawValue,
                "equipped":    false,
                "effect_json": "{}"
            ] as [String: any Sendable]
        }
        do {
            totems = try await SupabaseManager.shared.client
                .from("totems")
                .insert(starters)
                .select()
                .execute()
                .value
        } catch {
            errorText = error.localizedDescription
        }
    }
}

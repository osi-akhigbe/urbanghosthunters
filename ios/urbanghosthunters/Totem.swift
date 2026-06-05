import Foundation

enum TotemType: String, Codable, CaseIterable {
    case sealStability  = "seal_stability"
    case revealWindow   = "reveal_window"
    case flashCooldown  = "flash_cooldown"

    var displayName: String {
        switch self {
        case .sealStability: return "Seal Stabilizer"
        case .revealWindow:  return "Reveal Lens"
        case .flashCooldown: return "Spirit Flash"
        }
    }

    var effectDescription: String {
        switch self {
        case .sealStability: return "+5s to containment timer"
        case .revealWindow:  return "Doubles heading alignment window"
        case .flashCooldown: return "Halves action cooldown"
        }
    }

    var icon: String {
        switch self {
        case .sealStability: return "shield.lefthalf.filled"
        case .revealWindow:  return "eye.fill"
        case .flashCooldown: return "bolt.fill"
        }
    }
}

// Matches the totems table schema in Supabase
struct Totem: Identifiable, Codable {
    let id: UUID
    let user_id: UUID
    let type: TotemType
    var equipped: Bool
    let effect_json: [String: Double]
}

// Aggregated values applied to gameplay from all equipped totems
struct TotemEffects {
    var sealTimeBonus: Int = 0
    var alignmentWindowBonus: Double = 0
    var cooldownReduction: Double = 0
}

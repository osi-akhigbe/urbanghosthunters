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
struct GameTotem: Identifiable, Codable {
    let id: UUID
    let user_id: UUID
    let type: TotemType
    var equipped: Bool
}

// Aggregated values applied to gameplay from all equipped totems
struct TotemEffects {
    var sealTimeBonus: Int = 0
    var alignmentWindowBonus: Double = 0
    var cooldownReduction: Double = 0
}

// Reward granted after a containment attempt
struct ContainmentReward {
    let xp: Int
    let totemShards: Int
    let newTotem: TotemType?
}

struct RewardCalculator {
    // Returns the reward for a containment attempt based on difficulty and outcome.
    // Failed attempts always give 10 XP with no other rewards.
    // Higher difficulty gives more XP, shards, and a chance at a full totem.
    static func calculate(difficulty: Int, success: Bool) -> ContainmentReward {
        guard success else {
            return ContainmentReward(xp: 10, totemShards: 0, newTotem: nil)
        }
        switch difficulty {
        case 1:  return ContainmentReward(xp: 50,  totemShards: 0, newTotem: nil)
        case 2:  return ContainmentReward(xp: 75,  totemShards: 1, newTotem: nil)
        case 3:  return ContainmentReward(xp: 100, totemShards: 2, newTotem: nil)
        case 4:  return ContainmentReward(xp: 150, totemShards: 3,
                                          newTotem: Bool.random() ? TotemType.allCases.randomElement() : nil)
        default: return ContainmentReward(xp: 200, totemShards: 3,
                                          newTotem: TotemType.allCases.randomElement())
        }
    }
}

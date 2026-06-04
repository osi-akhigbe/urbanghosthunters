import Foundation

/// Scales containment challenge by hotspot difficulty (1–3).
struct HotspotDifficultyConfig {
    let timerSeconds: Int
    let minSealPoints: Int
    let sealCloseDistance: CGFloat
    let attackIntervalSeconds: Double
    let shieldMax: Int
    let attackShieldDamage: Int

    static func config(for difficulty: Int) -> HotspotDifficultyConfig {
        switch max(1, min(3, difficulty)) {
        case 1:
            return HotspotDifficultyConfig(
                timerSeconds: 15,
                minSealPoints: 20,
                sealCloseDistance: 60,
                attackIntervalSeconds: 8,
                shieldMax: 100,
                attackShieldDamage: 15
            )
        case 2:
            return HotspotDifficultyConfig(
                timerSeconds: 12,
                minSealPoints: 30,
                sealCloseDistance: 50,
                attackIntervalSeconds: 5,
                shieldMax: 90,
                attackShieldDamage: 20
            )
        default:
            return HotspotDifficultyConfig(
                timerSeconds: 8,
                minSealPoints: 40,
                sealCloseDistance: 40,
                attackIntervalSeconds: 3,
                shieldMax: 75,
                attackShieldDamage: 25
            )
        }
    }
}

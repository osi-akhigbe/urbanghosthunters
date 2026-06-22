import SwiftUI
import UIKit

enum GhostSkin: String, CaseIterable, Identifiable {
    case classic, inferno, void, toxic, ancient

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .inferno: return "Inferno"
        case .void:    return "Void"
        case .toxic:   return "Toxic"
        case .ancient: return "Ancient"
        }
    }

    var description: String {
        switch self {
        case .classic: return "The original specter"
        case .inferno: return "Born from hellfire"
        case .void:    return "Darkness given form"
        case .toxic:   return "Corrupted by radiation"
        case .ancient: return "A spirit of old gold"
        }
    }

    var icon: String {
        switch self {
        case .classic: return "drop.fill"
        case .inferno: return "flame.fill"
        case .void:    return "moon.stars.fill"
        case .toxic:   return "allergens"
        case .ancient: return "sparkles"
        }
    }

    // SwiftUI color — used in the scanner's SwiftUI ghost overlay
    var tint: Color {
        switch self {
        case .classic: return Color(red: 0.80, green: 0.96, blue: 1.00)
        case .inferno: return Color(red: 1.00, green: 0.28, blue: 0.05)
        case .void:    return Color(red: 0.60, green: 0.10, blue: 0.90)
        case .toxic:   return Color(red: 0.25, green: 0.95, blue: 0.15)
        case .ancient: return Color(red: 1.00, green: 0.78, blue: 0.18)
        }
    }

    // UIColor for RealityKit UnlitMaterial (body)
    var bodyUIColor: UIColor {
        switch self {
        case .classic: return UIColor(red: 0.80, green: 0.96, blue: 1.00, alpha: 1)
        case .inferno: return UIColor(red: 1.00, green: 0.28, blue: 0.05, alpha: 1)
        case .void:    return UIColor(red: 0.60, green: 0.10, blue: 0.90, alpha: 1)
        case .toxic:   return UIColor(red: 0.25, green: 0.95, blue: 0.15, alpha: 1)
        case .ancient: return UIColor(red: 1.00, green: 0.78, blue: 0.18, alpha: 1)
        }
    }

    // UIColor for RealityKit UnlitMaterial (eyes)
    var eyeUIColor: UIColor {
        switch self {
        case .classic: return UIColor(red: 0.06, green: 0.02, blue: 0.18, alpha: 1)
        case .inferno: return UIColor(red: 0.98, green: 0.95, blue: 0.90, alpha: 1)
        case .void:    return UIColor(red: 0.96, green: 0.96, blue: 1.00, alpha: 1)
        case .toxic:   return UIColor(red: 0.04, green: 0.18, blue: 0.04, alpha: 1)
        case .ancient: return UIColor(red: 0.05, green: 0.03, blue: 0.00, alpha: 1)
        }
    }
}

// MARK: - Manager

@Observable
@MainActor
final class GhostSkinManager {
    static let shared = GhostSkinManager()
    private init() {
        let raw = UserDefaults.standard.string(forKey: "activeSkin") ?? "classic"
        activeSkin = GhostSkin(rawValue: raw) ?? .classic
    }

    var activeSkin: GhostSkin = .classic {
        didSet { UserDefaults.standard.set(activeSkin.rawValue, forKey: "activeSkin") }
    }
}

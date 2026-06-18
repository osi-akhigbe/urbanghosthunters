import SwiftUI

// Shared palette and typography for the ghost-hunting kit HUD.
enum Kit {
    enum Colors {
        static let background = Color(red: 0.012, green: 0.0, blue: 0.118)   // #03001e
        static let panel = Color.white.opacity(0.06)
        static let panelBorder = Color.white.opacity(0.12)
        static let accent = Color(red: 0.49, green: 0.23, blue: 0.93)        // purple
        static let signal = Color(red: 0.0, green: 1.0, blue: 0.533)         // #00ff88
        static let warning = Color(red: 1.0, green: 0.78, blue: 0.2)
        static let danger = Color(red: 1.0, green: 0.32, blue: 0.32)
        static let label = Color.white.opacity(0.55)
        static let muted = Color.white.opacity(0.35)
        static let grid = accent.opacity(0.08)
    }

    enum Font {
        static func module() -> SwiftUI.Font {
            .system(size: 11, weight: .bold, design: .monospaced)
        }

        static func label() -> SwiftUI.Font {
            .system(size: 10, weight: .semibold, design: .monospaced)
        }

        static func readout(_ size: CGFloat = 28) -> SwiftUI.Font {
            .system(size: size, weight: .bold, design: .monospaced)
        }

        static func body() -> SwiftUI.Font {
            .system(size: 15, weight: .medium)
        }

        static func title() -> SwiftUI.Font {
            .system(size: 17, weight: .semibold)
        }
    }

    enum Layout {
        static let cornerRadius: CGFloat = 10
        static let panelPadding: CGFloat = 14
        static let labelTracking: CGFloat = 1.5
    }
}

extension View {
    func kitScreen() -> some View {
        self
            .background(Kit.Colors.background.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }
}

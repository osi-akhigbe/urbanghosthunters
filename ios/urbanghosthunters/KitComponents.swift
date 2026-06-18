import SwiftUI

// MARK: - Background

struct KitScreenBackground: View {
    var body: some View {
        ZStack {
            Kit.Colors.background.ignoresSafeArea()
            GridPattern()
                .stroke(Kit.Colors.grid, lineWidth: 1)
                .ignoresSafeArea()
        }
    }
}

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 30
        var x: CGFloat = 0
        while x <= rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }
        var y: CGFloat = 0
        while y <= rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }
        return path
    }
}

// MARK: - Labels & panels

struct KitSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Kit.Font.label())
            .foregroundStyle(Kit.Colors.accent)
            .tracking(Kit.Layout.labelTracking)
    }
}

struct KitPanel<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Kit.Layout.panelPadding)
            .background(Kit.Colors.panel, in: RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
                    .stroke(Kit.Colors.panelBorder, lineWidth: 1)
            )
    }
}

// MARK: - HUD header

struct KitHUDHeader: View {
    let module: String
    let title: String
    var subtitle: String? = nil
    var readout: KitReadout? = nil

    struct KitReadout {
        let label: String
        let value: String
        var valueColor: Color = Kit.Colors.signal
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(module)
                    .font(Kit.Font.module())
                    .foregroundStyle(Kit.Colors.accent)
                    .tracking(Kit.Layout.labelTracking)

                Text(title)
                    .font(Kit.Font.title())
                    .foregroundStyle(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(Kit.Font.label())
                        .foregroundStyle(Kit.Colors.muted)
                }
            }

            Spacer()

            if let readout {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(readout.value)
                        .font(Kit.Font.readout(26))
                        .foregroundStyle(readout.valueColor)
                        .monospacedDigit()

                    Text(readout.label)
                        .font(Kit.Font.label())
                        .foregroundStyle(Kit.Colors.label)
                        .tracking(Kit.Layout.labelTracking)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Meters

struct KitMeterBar: View {
    let label: String
    let level: Double
    var suffix: String? = nil
    var tint: Color = Kit.Colors.accent
    var height: CGFloat = 10

    private var displayValue: String {
        if let suffix { return suffix }
        return "\(Int(level * 100))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(Kit.Font.label())
                    .foregroundStyle(Kit.Colors.label)
                    .tracking(Kit.Layout.labelTracking)

                Spacer()

                Text(displayValue)
                    .font(Kit.Font.label())
                    .foregroundStyle(Kit.Colors.muted)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Kit.Colors.panel)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.5), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * level))
                        .animation(.easeInOut(duration: 0.3), value: level)
                }
            }
            .frame(height: height)
        }
    }
}

struct KitCompassMeter: View {
    let alignment: Double
    let degrees: Double

    var body: some View {
        KitMeterBar(
            label: "HEADING ALIGNMENT",
            level: alignment,
            suffix: "\(Int(degrees))°",
            tint: Kit.Colors.accent,
            height: 12
        )
    }
}

struct KitProximityMeter: View {
    let level: Double

    private var tint: Color {
        if level > 0.7 { return Kit.Colors.signal }
        if level > 0.4 { return Kit.Colors.warning }
        return Kit.Colors.danger
    }

    var body: some View {
        KitMeterBar(
            label: "PROXIMITY SIGNAL",
            level: level,
            tint: tint,
            height: 12
        )
    }
}

struct KitSignalBars: View {
    let level: Double
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(Kit.Font.label())
                    .foregroundStyle(Kit.Colors.label)
                    .tracking(Kit.Layout.labelTracking)
                Spacer()
                Text("\(Int(level * 100))%")
                    .font(Kit.Font.label())
                    .foregroundStyle(Kit.Colors.muted)
                    .monospacedDigit()
            }

            HStack(spacing: 4) {
                ForEach(0..<8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Double(i) / 8.0 < level ? Kit.Colors.signal : Kit.Colors.panel)
                        .frame(width: 18, height: Double(i + 1) * 4 + 8)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Chips & buttons

struct KitChip: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(Kit.Font.label())
            .foregroundStyle(Kit.Colors.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Kit.Colors.accent.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Kit.Colors.accent.opacity(0.3), lineWidth: 1))
    }
}

struct KitPrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Kit.Font.module())
                .tracking(1)
                .foregroundStyle(enabled ? Kit.Colors.background : Kit.Colors.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    enabled ? Kit.Colors.accent : Kit.Colors.panel,
                    in: RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
                        .stroke(enabled ? Kit.Colors.accent.opacity(0.6) : Kit.Colors.panelBorder, lineWidth: 1)
                )
        }
        .disabled(!enabled)
    }
}

struct KitGhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Kit.Font.label())
                .foregroundStyle(Kit.Colors.accent)
        }
    }
}

// MARK: - Feedback states

    var message: String = "SYNCING…"

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Kit.Colors.accent)
                .scaleEffect(1.2)

            Text(message)
                .font(Kit.Font.label())
                .foregroundStyle(Kit.Colors.label)
                .tracking(Kit.Layout.labelTracking)
        }
    }
}

struct KitEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(Kit.Colors.muted)

            Text(title)
                .font(Kit.Font.title())
                .foregroundStyle(Kit.Colors.label)

            if let message {
                Text(message)
                    .font(Kit.Font.body())
                    .foregroundStyle(Kit.Colors.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }
}

struct KitBanner: View {
    enum Style {
        case error, success, alert

        var color: Color {
            switch self {
            case .error:   return Kit.Colors.danger
            case .success: return Kit.Colors.signal
            case .alert:   return Kit.Colors.accent
            }
        }

        var icon: String {
            switch self {
            case .error:   return "exclamationmark.triangle.fill"
            case .success: return "checkmark.circle.fill"
            case .alert:   return "antenna.radiowaves.left.and.right"
            }
        }
    }

    let style: Style
    let title: String
    var message: String? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: style.icon)
                .font(.title3)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Kit.Font.title())
                    .foregroundStyle(.white)

                if let message {
                    Text(message)
                        .font(Kit.Font.label())
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            Spacer()

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
                .fill(style.color.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        .padding(.horizontal, 16)
    }
}

struct KitOutcomeSheet: View {
    let success: Bool
    let title: String
    let subtitle: String
    let reward: String
    let buttonTitle: String
    let onDismiss: () -> Void

    private var accent: Color { success ? Kit.Colors.signal : Kit.Colors.danger }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: success ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(accent)

            VStack(spacing: 6) {
                Text(title)
                    .font(Kit.Font.readout(22))
                    .foregroundStyle(accent)

                Text(subtitle)
                    .font(Kit.Font.body())
                    .foregroundStyle(Kit.Colors.label)
            }

            Text(reward)
                .font(Kit.Font.readout(20))
                .foregroundStyle(Kit.Colors.accent)

            KitPrimaryButton(title: buttonTitle, action: onDismiss)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationBackground(Kit.Colors.background)
    }
}

struct KitTextField: View {
    let label: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Kit.Font.label())
                .foregroundStyle(Kit.Colors.label)
                .tracking(Kit.Layout.labelTracking)

            TextField("", text: $text)
                .font(Kit.Font.body())
                .foregroundStyle(.white)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .padding(12)
                .background(Kit.Colors.panel, in: RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
                        .stroke(Kit.Colors.panelBorder, lineWidth: 1)
                )
        }
    }
}

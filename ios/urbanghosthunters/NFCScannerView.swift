import SwiftUI

struct NFCScannerView: View {
    @State private var nfc = NFCManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            KitScreenBackground()

            VStack(spacing: 32) {
                Spacer()

                stateIcon
                    .font(.system(size: 64))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.pulse, isActive: nfc.scanState == .scanning)

                stateText

                if case .scanning = nfc.scanState {
                    ProgressView()
                        .tint(Kit.Colors.accent)
                }

                Spacer()

                actionButton

                if nfc.scanState != .idle && nfc.scanState != .scanning {
                    Button("DISMISS") {
                        nfc.dismiss()
                        dismiss()
                    }
                    .font(Kit.Font.label())
                    .foregroundStyle(Kit.Colors.muted)
                }
            }
            .padding(24)
        }
        .kitScreen()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Kit.Colors.background)
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch nfc.scanState {
        case .idle:
            Image(systemName: "wave.3.right.circle")
        case .scanning:
            Image(systemName: "wave.3.right.circle.fill")
        case .found(let record):
            Image(systemName: record.isTotemTag ? "person.crop.circle.badge.checkmark" : "key.fill")
        case .unknownUID:
            Image(systemName: "questionmark.circle")
        case .unavailable:
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
        case .error:
            Image(systemName: "exclamationmark.triangle")
        }
    }

    private var iconColor: Color {
        switch nfc.scanState {
        case .idle, .scanning:                   return Kit.Colors.accent
        case .found:                             return Kit.Colors.signal
        case .unknownUID, .error, .unavailable:  return .red
        }
    }

    @ViewBuilder
    private var stateText: some View {
        switch nfc.scanState {
        case .idle:
            VStack(spacing: 8) {
                Text("SCAN TOTEM")
                    .font(Kit.Font.title())
                    .foregroundStyle(.white)
                Text("Tap a physical NFC totem to unlock its power.")
                    .font(Kit.Font.body())
                    .foregroundStyle(Kit.Colors.muted)
                    .multilineTextAlignment(.center)
            }

        case .scanning:
            Text("SCANNING…")
                .font(Kit.Font.title())
                .foregroundStyle(Kit.Colors.accent)

        case .found(let record):
            VStack(spacing: 8) {
                Text("TOTEM FOUND")
                    .font(Kit.Font.module())
                    .foregroundStyle(Kit.Colors.signal)
                    .tracking(Kit.Layout.labelTracking)
                Text(record.label)
                    .font(Kit.Font.title())
                    .foregroundStyle(.white)
                if let type = record.resolvedTotemType {
                    Text(type.effectDescription)
                        .font(Kit.Font.label())
                        .foregroundStyle(Kit.Colors.label)
                } else if let key = record.key_name {
                    Text("Key: \(key)")
                        .font(Kit.Font.label())
                        .foregroundStyle(Kit.Colors.label)
                }
            }

        case .unknownUID(let uid):
            VStack(spacing: 8) {
                Text("UNKNOWN TAG")
                    .font(Kit.Font.module())
                    .foregroundStyle(.red)
                    .tracking(Kit.Layout.labelTracking)
                Text("UID \(uid) is not registered.")
                    .font(Kit.Font.label())
                    .foregroundStyle(Kit.Colors.muted)
                    .multilineTextAlignment(.center)
            }

        case .unavailable:
            VStack(spacing: 8) {
                Text("NFC UNAVAILABLE")
                    .font(Kit.Font.module())
                    .foregroundStyle(.red)
                    .tracking(Kit.Layout.labelTracking)
                Text("This device does not support NFC tag reading.")
                    .font(Kit.Font.label())
                    .foregroundStyle(Kit.Colors.muted)
                    .multilineTextAlignment(.center)
            }

        case .error(let message):
            VStack(spacing: 8) {
                Text("SCAN ERROR")
                    .font(Kit.Font.module())
                    .foregroundStyle(.red)
                    .tracking(Kit.Layout.labelTracking)
                Text(message)
                    .font(Kit.Font.label())
                    .foregroundStyle(Kit.Colors.muted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch nfc.scanState {
        case .idle, .unknownUID, .error, .unavailable:
            KitPrimaryButton(title: nfc.scanState == .idle ? "SCAN" : "TRY AGAIN") {
                nfc.startScan()
            }
        case .found:
            KitPrimaryButton(title: "DONE") {
                nfc.dismiss()
                dismiss()
            }
        case .scanning:
            EmptyView()
        }
    }
}

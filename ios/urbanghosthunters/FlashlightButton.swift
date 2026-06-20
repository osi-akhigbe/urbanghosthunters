import SwiftUI

struct FlashlightButton: View {
    let manager: FlashlightManager
    var isLowLight: Bool = false

    var body: some View {
        if manager.hasTorch {
            Button {
                manager.toggle()
            } label: {
                Image(systemName: manager.isOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.title2)
                    .foregroundStyle(manager.isOn ? Color.yellow : Kit.Colors.accent)
                    .padding(10)
                    .background(
                        manager.isOn
                            ? Color.yellow.opacity(0.15)
                            : Kit.Colors.accent.opacity(0.1),
                        in: Circle()
                    )
                    .overlay(
                        Circle().stroke(
                            manager.isOn
                                ? Color.yellow.opacity(0.5)
                                : Kit.Colors.accent.opacity(0.3),
                            lineWidth: 1
                        )
                    )
                    .symbolEffect(.pulse, isActive: !manager.isOn && isLowLight)
            }
            .accessibilityLabel(manager.isOn ? "Turn flashlight off" : "Turn flashlight on")
        }
    }
}

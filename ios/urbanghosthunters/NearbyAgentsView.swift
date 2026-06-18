//
//  NearbyAgentsView.swift
//  urbanghosthunters
//

import SwiftUI

struct NearbyAgentsView: View {
    @State private var ble = BLEAgentManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.purple)
                Text("NEARBY AGENTS")
                    .font(.caption).bold()
                    .foregroundStyle(.purple)
                    .tracking(2)
                Spacer()
                // Pulsing dot indicator
                Circle()
                    .fill(ble.isScanning ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }

            if let error = ble.errorText {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if ble.nearbyAgents.isEmpty {
                Text("No agents detected nearby")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ForEach(ble.nearbyAgents, id: \.self) { agentId in
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Text("Agent \(agentId.prefix(8).uppercased())")
                            .font(.caption)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("IN RANGE")
                            .font(.caption2).bold()
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .onAppear { ble.start() }
        .onDisappear { ble.stop() }
    }
}

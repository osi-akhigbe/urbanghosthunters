import SwiftUI

struct InventoryView: View {
    @State private var vm = InventoryViewModel.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if vm.isLoading {
                    ProgressView()
                        .tint(.purple)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            EquippedSlotsSection(equipped: vm.equippedTotems)
                            TotemListSection(totems: vm.totems, onTap: { totem in
                                Task { await vm.toggleEquip(totem) }
                            })
                        }
                        .padding()
                    }
                }

                if let error = vm.errorText {
                    VStack {
                        Spacer()
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                            .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        // Fetch totems as soon as the view appears
        .task { await vm.fetch() }
    }
}

// MARK: - Equipped Slots

// Shows one slot per totem type; filled slots display the totem icon
private struct EquippedSlotsSection: View {
    let equipped: [Totem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EQUIPPED")
                .font(.caption).bold()
                .foregroundStyle(.purple)

            HStack(spacing: 12) {
                ForEach(TotemType.allCases, id: \.self) { type in
                    let totem = equipped.first(where: { $0.type == type })
                    EquippedSlot(type: type, isOccupied: totem != nil)
                }
            }
        }
    }
}

// Single equipment slot — shows the icon when filled, a plus when empty
private struct EquippedSlot: View {
    let type: TotemType
    let isOccupied: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOccupied ? Color.purple : Color.white.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 72, height: 72)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isOccupied ? Color.purple.opacity(0.15) : Color.white.opacity(0.05))
                    )

                if isOccupied {
                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundStyle(.purple)
                } else {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.2))
                }
            }

            Text(isOccupied ? type.displayName : "Empty")
                .font(.caption2)
                .foregroundStyle(isOccupied ? .white : .white.opacity(0.3))
                .lineLimit(1)
                .frame(width: 72)
        }
    }
}

// MARK: - Totem List

// Lists all totems the user owns with an equip / unequip button on each
private struct TotemListSection: View {
    let totems: [Totem]
    let onTap: (Totem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOTEMS")
                .font(.caption).bold()
                .foregroundStyle(.purple)

            if totems.isEmpty {
                Text("No totems found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(totems) { totem in
                    TotemRow(totem: totem, onTap: { onTap(totem) })
                }
            }
        }
    }
}

// A single row showing the totem icon, name, effect description, and equip toggle
private struct TotemRow: View {
    let totem: Totem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: totem.type.icon)
                    .font(.title2)
                    .foregroundStyle(.purple)
                    .frame(width: 40, height: 40)
                    .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(totem.type.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(totem.type.effectDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(totem.equipped ? "Equipped" : "Equip")
                    .font(.caption).bold()
                    .foregroundStyle(totem.equipped ? .black : .purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(totem.equipped ? Color.purple : Color.purple.opacity(0.15),
                                in: Capsule())
            }
            .padding()
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

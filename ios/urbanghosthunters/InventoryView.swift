import SwiftUI

struct InventoryView: View {
<<<<<<< HEAD
    @State private var inventory = PlayerInventory.shared
=======
    @State private var vm = InventoryViewModel.shared
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

<<<<<<< HEAD
                if inventory.ownedTotems.isEmpty && inventory.errorText == nil {
=======
                if vm.isLoading {
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                    ProgressView()
                        .tint(.purple)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
<<<<<<< HEAD
                            VStack(alignment: .leading, spacing: 12) {
                                Text("EQUIPPED")
                                    .font(.caption).bold()
                                    .foregroundStyle(.purple)

                                if let equipped = inventory.equippedTotem {
                                    HStack(spacing: 16) {
                                        Image(systemName: "shield.fill")
                                            .font(.title2)
                                            .foregroundStyle(.purple)
                                            .frame(width: 40, height: 40)
                                            .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(equipped.name)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Text(equipped.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text("Bonus: \(equipped.bonus_type)")
                                                .font(.caption2)
                                                .foregroundStyle(.purple)
                                        }
                                        Spacer()
                                        Text("Equipped")
                                            .font(.caption).bold()
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.purple, in: Capsule())
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                                } else {
                                    Text("No totem equipped. Earn one from a successful containment.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("INVENTORY")
                                    .font(.caption).bold()
                                    .foregroundStyle(.purple)

                                if inventory.ownedTotems.isEmpty {
                                    Text("No totems yet. Capture a ghost to earn Spirit Ward.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 8)
                                } else {
                                    ForEach(inventory.ownedTotems) { row in
                                        if let totem = row.totems {
                                            Button {
                                                Task { await inventory.equip(totemId: totem.id) }
                                            } label: {
                                                HStack(spacing: 16) {
                                                    Image(systemName: "sparkles")
                                                        .font(.title2)
                                                        .foregroundStyle(.purple)
                                                        .frame(width: 40, height: 40)
                                                        .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(totem.name)
                                                            .font(.headline)
                                                            .foregroundStyle(.white)
                                                        Text(totem.description)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                    Spacer()
                                                    Text(row.equipped ? "Equipped" : "Equip")
                                                        .font(.caption).bold()
                                                        .foregroundStyle(row.equipped ? .black : .purple)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(row.equipped ? Color.purple : Color.purple.opacity(0.15), in: Capsule())
                                                }
                                                .padding()
                                                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
=======
                            EquippedSlotsSection(equipped: vm.equippedTotems)
                            TotemListSection(totems: vm.totems, onTap: { totem in
                                Task { await vm.toggleEquip(totem) }
                            })
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
                        }
                        .padding()
                    }
                }

<<<<<<< HEAD
                if let error = inventory.errorText {
=======
                if let error = vm.errorText {
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem
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
<<<<<<< HEAD
        .task { await inventory.load() }
    }
}
=======
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
>>>>>>> origin/feature/APPDEV-38/reward-xp-totem

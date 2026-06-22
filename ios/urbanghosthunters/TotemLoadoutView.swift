import SwiftUI

struct TotemLoadoutView: View {
    @State private var inventory = PlayerInventory.shared

    var body: some View {
        List {
            if let equipped = inventory.equippedTotem {
                Section("Equipped") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(equipped.name).font(.headline)
                        Text(equipped.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section {
                    Text("No totem equipped. Earn one from a successful containment.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Inventory") {
                if inventory.ownedTotems.isEmpty {
                    Text("No totems yet. Capture a ghost to earn Spirit Ward.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(inventory.ownedTotems) { row in
                        if let totem = row.totems {
                            Button {
                                Task { await inventory.equip(totemId: totem.id) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(totem.name).foregroundStyle(.primary)
                                        Text(totem.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if row.equipped {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.purple)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if let err = inventory.errorText {
                Section {
                    Text(err).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Loadout")
        .task { await inventory.load() }
        .refreshable { await inventory.load() }
    }
}

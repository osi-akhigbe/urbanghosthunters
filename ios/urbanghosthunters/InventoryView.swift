import SwiftUI

struct InventoryView: View {
    @State private var inventory = PlayerInventory.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if inventory.ownedTotems.isEmpty && inventory.errorText == nil {
                    ProgressView()
                        .tint(.purple)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
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
                        }
                        .padding()
                    }
                }

                if let error = inventory.errorText {
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
        .task { await inventory.load() }
    }
}
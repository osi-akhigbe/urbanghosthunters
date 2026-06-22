import SwiftUI

struct InventoryView: View {
    @State private var vm = InventoryViewModel.shared

    var body: some View {
        NavigationStack {
            ZStack {
                KitScreenBackground()

                if vm.isLoading {
                    KitLoadingView(message: "LOADING TOTEMS…")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            EquippedSlotsSection(equipped: vm.equippedTotems)
                            TotemListSection(totems: vm.totems, onTap: { totem in
                                Task { await vm.toggleEquip(totem) }
                            })
                            SkinPickerSection()
                        }
                        .padding(16)
                    }
                }

                if let error = vm.errorText {
                    VStack {
                        Spacer()
                        KitBanner(style: .error, title: "SYNC ERROR", message: error)
                            .padding(.bottom, 16)
                    }
                }
            }
            .kitScreen()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("INVENTORY")
                        .font(Kit.Font.module())
                        .foregroundStyle(Kit.Colors.accent)
                        .tracking(Kit.Layout.labelTracking)
                }
            }
            .toolbarBackground(Kit.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task { await vm.fetch() }
    }
}

private struct EquippedSlotsSection: View {
    let equipped: [GameTotem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            KitSectionLabel(text: "EQUIPPED")

            HStack(spacing: 12) {
                ForEach(TotemType.allCases, id: \.self) { type in
                    let totem = equipped.first(where: { $0.type == type })
                    EquippedSlot(type: type, isOccupied: totem != nil)
                }
            }
        }
    }
}

private struct EquippedSlot: View {
    let type: TotemType
    let isOccupied: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
                    .fill(isOccupied ? Kit.Colors.accent.opacity(0.12) : Kit.Colors.panel)
                    .frame(width: 72, height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
                            .stroke(isOccupied ? Kit.Colors.accent : Kit.Colors.panelBorder, lineWidth: 1.5)
                    )

                Image(systemName: isOccupied ? type.icon : "plus")
                    .font(.title2)
                    .foregroundStyle(isOccupied ? Kit.Colors.accent : Kit.Colors.muted)
            }

            Text(isOccupied ? type.displayName : "EMPTY")
                .font(Kit.Font.label())
                .foregroundStyle(isOccupied ? .white : Kit.Colors.muted)
                .lineLimit(1)
                .frame(width: 72)
        }
    }
}

private struct TotemListSection: View {
    let totems: [GameTotem]
    let onTap: (GameTotem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            KitSectionLabel(text: "TOTEMS")

            if totems.isEmpty {
                KitEmptyState(
                    icon: "backpack",
                    title: "NO TOTEMS",
                    message: "Complete encounters to collect gear."
                )
                .frame(maxWidth: .infinity)
            } else {
                ForEach(totems) { totem in
                    TotemRow(totem: totem, onTap: { onTap(totem) })
                }
            }
        }
    }
}

private struct TotemRow: View {
    let totem: GameTotem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: totem.type.icon)
                    .font(.title2)
                    .foregroundStyle(Kit.Colors.accent)
                    .frame(width: 44, height: 44)
                    .background(Kit.Colors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius))

                VStack(alignment: .leading, spacing: 4) {
                    Text(totem.type.displayName)
                        .font(Kit.Font.title())
                        .foregroundStyle(.white)
                    Text(totem.type.effectDescription)
                        .font(Kit.Font.label())
                        .foregroundStyle(Kit.Colors.label)
                }

                Spacer()

                Text(totem.equipped ? "EQUIPPED" : "EQUIP")
                    .font(Kit.Font.label())
                    .foregroundStyle(totem.equipped ? Kit.Colors.background : Kit.Colors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        totem.equipped ? Kit.Colors.accent : Kit.Colors.accent.opacity(0.12),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule().stroke(Kit.Colors.accent.opacity(totem.equipped ? 0 : 0.4), lineWidth: 1)
                    )
            }
            .padding(Kit.Layout.panelPadding)
            .background(Kit.Colors.panel, in: RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
                    .stroke(Kit.Colors.panelBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ghost Skin Picker

private struct SkinPickerSection: View {
    @State private var skinManager = GhostSkinManager.shared

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            KitSectionLabel(text: "GHOST SKINS")

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(GhostSkin.allCases) { skin in
                    SkinCard(skin: skin, isActive: skinManager.activeSkin == skin) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            skinManager.activeSkin = skin
                        }
                    }
                }
            }
        }
    }
}

private struct SkinCard: View {
    let skin: GhostSkin
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(skin.tint.opacity(0.18))
                        .frame(width: 56, height: 56)

                    Circle()
                        .fill(skin.tint.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .blur(radius: 4)

                    Image(systemName: skin.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(skin.tint)
                }

                VStack(spacing: 3) {
                    Text(skin.displayName)
                        .font(Kit.Font.title())
                        .foregroundStyle(isActive ? skin.tint : .white)

                    Text(skin.description)
                        .font(Kit.Font.label())
                        .foregroundStyle(Kit.Colors.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                isActive ? skin.tint.opacity(0.10) : Kit.Colors.panel,
                in: RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Kit.Layout.cornerRadius)
                    .stroke(
                        isActive ? skin.tint : Kit.Colors.panelBorder,
                        lineWidth: isActive ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

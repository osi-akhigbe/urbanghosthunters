import SwiftUI
import Supabase

struct EncounterRow: Decodable, Identifiable, Hashable {
    let id: UUID
    let hotspot_id: UUID
    let created_at: String?
    let outcome: String
    let rewards_json: RewardsJSON?

    struct RewardsJSON: Decodable, Hashable {
        let xp: Int?
        let totem_shards: Int?
        let totem_granted: String?
    }

    var formattedDate: String {
        guard let created_at else { return "Unknown date" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: created_at) else { return created_at }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

@Observable
@MainActor
final class JournalViewModel {
    var encounters: [EncounterRow] = []
    var errorText: String?
    var isLoading = false

    func load() async {
        guard SupabaseManager.shared.isSignedIn else {
            errorText = "Sign in to view your journal."
            return
        }

        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            encounters = try await SupabaseManager.shared.client
                .from("encounters")
                .select("id, hotspot_id, created_at, outcome, rewards_json")
                .order("created_at", ascending: false)
                .limit(30)
                .execute()
                .value
        } catch {
            ErrorLogger.shared.log(error, context: "JournalViewModel.load")
            errorText = error.localizedDescription
        }
    }
}

struct JournalView: View {
    @State private var vm = JournalViewModel()

    var body: some View {
        ZStack {
            KitScreenBackground()

            Group {
                if vm.isLoading {
                    KitLoadingView(message: "LOADING JOURNAL…")
                } else if let error = vm.errorText {
                    KitEmptyState(icon: "exclamationmark.triangle",
                                  title: "SYNC ERROR",
                                  message: error)
                } else if vm.encounters.isEmpty {
                    KitEmptyState(icon: "book.closed",
                                  title: "NO ENTRIES",
                                  message: "Complete a containment to log your first encounter.")
                } else {
                    List {
                        ForEach(vm.encounters) { row in
                            NavigationLink(value: row) {
                                JournalRowView(row: row)
                            }
                            .listRowBackground(Kit.Colors.panel)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("JOURNAL")
                    .font(Kit.Font.module())
                    .foregroundStyle(Kit.Colors.accent)
                    .tracking(Kit.Layout.labelTracking)
            }
        }
        .toolbarBackground(Kit.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(for: EncounterRow.self) { row in
            EncounterDetailView(encounter: row)
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

struct JournalRowView: View {
    let row: EncounterRow

    private var outcomeColor: Color {
        row.outcome == "captured" ? Kit.Colors.signal : Kit.Colors.danger
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.outcome == "captured" ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.title2)
                .foregroundStyle(outcomeColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.outcome == "captured" ? "Ghost Contained" : "Containment Failed")
                    .font(Kit.Font.title())
                    .foregroundStyle(.white)

                Text(row.formattedDate)
                    .font(Kit.Font.label())
                    .foregroundStyle(Kit.Colors.muted)
                    .tracking(Kit.Layout.labelTracking)

                HStack(spacing: 8) {
                    if let xp = row.rewards_json?.xp {
                        Text("+\(xp) XP")
                            .font(Kit.Font.label())
                            .foregroundStyle(Kit.Colors.signal)
                    }
                    if let shards = row.rewards_json?.totem_shards, shards > 0 {
                        Text("+\(shards) shards")
                            .font(Kit.Font.label())
                            .foregroundStyle(Kit.Colors.accent)
                    }
                    if let totem = row.rewards_json?.totem_granted {
                        Text("🔮 \(totem)")
                            .font(Kit.Font.label())
                            .foregroundStyle(Kit.Colors.accent)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct EncounterDetailView: View {
    let encounter: EncounterRow
    @State private var replayHotspot: Hotspot?

    var body: some View {
        ZStack {
            KitScreenBackground()

            List {
                Section("RESULT") {
                    LabeledContent("Outcome", value: encounter.outcome.capitalized)
                    LabeledContent("Date", value: encounter.formattedDate)
                    if let xp = encounter.rewards_json?.xp {
                        LabeledContent("XP Earned", value: "+\(xp)")
                    }
                    if let shards = encounter.rewards_json?.totem_shards, shards > 0 {
                        LabeledContent("Totem Shards", value: "+\(shards)")
                    }
                    if let totem = encounter.rewards_json?.totem_granted {
                        LabeledContent("Totem Unlocked", value: totem)
                    }
                }
                .listRowBackground(Kit.Colors.panel)

                Section {
                    Button("Replay hunt at this location") {
                        Task { await loadHotspotForReplay() }
                    }
                    .foregroundStyle(Kit.Colors.accent)
                }
                .listRowBackground(Kit.Colors.panel)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Encounter Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Kit.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(item: $replayHotspot) { hotspot in
            ScannerView(hotspot: hotspot)
        }
    }

    private func loadHotspotForReplay() async {
        do {
            let rows: [Hotspot] = try await SupabaseManager.shared.client
                .from("hotspots")
                .select()
                .eq("id", value: encounter.hotspot_id)
                .limit(1)
                .execute()
                .value
            replayHotspot = rows.first
        } catch {
            ErrorLogger.shared.log(error, context: "EncounterDetailView.loadHotspotForReplay")
        }
    }
}

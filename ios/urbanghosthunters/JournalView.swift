import SwiftUI
import Supabase

struct EncounterRow: Decodable, Identifiable, Hashable {
    let id: UUID
    let hotspot_id: UUID
    let created_at: String?
    let outcome: String
    let rewards_json: RewardsJSON?
    let hotspots: HotspotSummary?

    struct RewardsJSON: Decodable, Hashable {
        let xp: Int?
        let totem_name: String?
    }

    struct HotspotSummary: Decodable, Hashable {
        let name: String
        let difficulty: Int?
    }

    var displayTitle: String {
        hotspots?.name ?? "Unknown haunt"
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
                .select("id, hotspot_id, created_at, outcome, rewards_json, hotspots(name, difficulty)")
                .order("created_at", ascending: false)
                .limit(30)
                .execute()
                .value
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct JournalView: View {
    @State private var vm = JournalViewModel()

    var body: some View {
        List {
            if vm.isLoading {
                ProgressView("Loading encounters…")
            } else if let error = vm.errorText {
                Text(error).foregroundStyle(.red)
            } else if vm.encounters.isEmpty {
                Text("No encounters yet. Complete a containment to see results here.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.encounters) { row in
                    NavigationLink(value: row) {
                        JournalRowView(row: row)
                    }
                }
            }
        }
        .navigationTitle("Journal")
        .navigationDestination(for: EncounterRow.self) { row in
            EncounterDetailView(encounter: row)
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

struct JournalRowView: View {
    let row: EncounterRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.displayTitle)
                .font(.headline)
            Text(row.outcome.capitalized)
                .font(.subheadline)
                .foregroundStyle(row.outcome == "captured" ? .green : .orange)
            HStack {
                if let xp = row.rewards_json?.xp {
                    Text("+\(xp) XP")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
                if let totem = row.rewards_json?.totem_name {
                    Text("Totem: \(totem)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EncounterDetailView: View {
    let encounter: EncounterRow
    @State private var replayHotspot: Hotspot?

    var body: some View {
        List {
            Section("Haunt") {
                LabeledContent("Location", value: encounter.displayTitle)
                if let d = encounter.hotspots?.difficulty {
                    LabeledContent("Difficulty", value: "\(d)")
                }
            }
            Section("Result") {
                LabeledContent("Outcome", value: encounter.outcome.capitalized)
                if let xp = encounter.rewards_json?.xp {
                    LabeledContent("XP", value: "+\(xp)")
                }
                if let totem = encounter.rewards_json?.totem_name {
                    LabeledContent("Reward", value: totem)
                }
                if let created = encounter.created_at {
                    LabeledContent("When", value: created)
                }
            }
            Section {
                Button("Replay hunt at this haunt") {
                    Task { await loadHotspotForReplay() }
                }
            }
        }
        .navigationTitle("Encounter")
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
            print("Replay load failed: \(error)")
        }
    }
}

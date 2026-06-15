//
//  CoopSessionManager.swift
//  urbanghosthunters
//

import Foundation
import Supabase

enum CoopStatus: String {
    case waiting, heading, luring, sealing, complete, failed
}

struct CoopSession: Decodable {
    let id: UUID
    let hotspot_id: UUID
    let host_id: UUID
    let guest_id: UUID?
    let status: String
    let host_heading: Double
    let guest_heading: Double
    let host_seal_complete: Bool
    let guest_seal_complete: Bool
}

@Observable
@MainActor
final class CoopSessionManager {
    static let shared = CoopSessionManager()

    var session: CoopSession?
    var isHost = false
    var errorText: String?
    var statusMessage = "Waiting for partner…"

    private var realtimeChannel: RealtimeChannelV2?

    private init() {}

    // MARK: - Host: create session
    func createSession(hotspotId: UUID) async {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { return }

        struct Insert: Encodable {
            let hotspot_id: UUID
            let host_id: UUID
            let status: String
        }

        do {
            let sessions: [CoopSession] = try await SupabaseManager.shared.client
                .from("coop_sessions")
                .insert(Insert(hotspot_id: hotspotId, host_id: userId, status: "waiting"))
                .select()
                .execute()
                .value
            session = sessions.first
            isHost = true
            statusMessage = "Waiting for partner to join…"
            if let session { await subscribeToSession(sessionId: session.id) }
        } catch {
            ErrorLogger.shared.log(error, context: "CoopSessionManager.createSession")
            errorText = error.localizedDescription
        }
    }

    // MARK: - Guest: join session
    func joinSession(sessionId: UUID) async {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { return }

        struct Patch: Encodable {
            let guest_id: UUID
            let status: String
        }

        do {
            let sessions: [CoopSession] = try await SupabaseManager.shared.client
                .from("coop_sessions")
                .update(Patch(guest_id: userId, status: "heading"))
                .eq("id", value: sessionId)
                .select()
                .execute()
                .value
            session = sessions.first
            isHost = false
            statusMessage = "Align your heading with your partner"
            if let session { await subscribeToSession(sessionId: session.id) }
        } catch {
            ErrorLogger.shared.log(error, context: "CoopSessionManager.joinSession")
            errorText = error.localizedDescription
        }
    }

    // MARK: - Update heading
    func updateHeading(_ heading: Double) async {
        guard let session else { return }
        let field = isHost ? "host_heading" : "guest_heading"
        do {
            try await SupabaseManager.shared.client
                .from("coop_sessions")
                .update([field: heading])
                .eq("id", value: session.id)
                .execute()
        } catch {
            ErrorLogger.shared.log(error, context: "CoopSessionManager.updateHeading")
        }
    }

    // MARK: - Mark seal complete
    func markSealComplete() async {
        guard let session else { return }
        let field = isHost ? "host_seal_complete" : "guest_seal_complete"
        do {
            try await SupabaseManager.shared.client
                .from("coop_sessions")
                .update([field: true])
                .eq("id", value: session.id)
                .execute()
        } catch {
            ErrorLogger.shared.log(error, context: "CoopSessionManager.markSealComplete")
        }
    }

    // MARK: - Advance status
    func advanceStatus(to status: CoopStatus) async {
        guard let session else { return }
        do {
            try await SupabaseManager.shared.client
                .from("coop_sessions")
                .update(["status": status.rawValue])
                .eq("id", value: session.id)
                .execute()
        } catch {
            ErrorLogger.shared.log(error, context: "CoopSessionManager.advanceStatus")
        }
    }

    // MARK: - Realtime subscription
    func subscribeToSession(sessionId: UUID) async {
        let channel = await SupabaseManager.shared.client.realtimeV2.channel("coop_\(sessionId)")

        await channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "coop_sessions",
            filter: "id=eq.\(sessionId.uuidString)"
        ) { [weak self] change in
            Task { @MainActor in
                guard let self else { return }
                if let updated = try? change.decodeRecord(as: CoopSession.self, decoder: JSONDecoder()) {
                    self.session = updated
                    self.updateStatusMessage(updated)
                }
            }
        }

        await channel.subscribe()
        realtimeChannel = channel
    }

    private func updateStatusMessage(_ session: CoopSession) {
        switch CoopStatus(rawValue: session.status) ?? .waiting {
        case .waiting:
            statusMessage = "Waiting for partner to join…"
        case .heading:
            let diff = abs(session.host_heading - session.guest_heading)
            let aligned = min(diff, 360 - diff) < 20
            statusMessage = aligned ? "✅ Headings aligned! Ready to lure" : "Align your heading with your partner"
        case .luring:
            statusMessage = "Both hold to lure the ghost…"
        case .sealing:
            let hostDone = session.host_seal_complete
            let guestDone = session.guest_seal_complete
            if hostDone && guestDone {
                statusMessage = "✅ Seal complete!"
                Task { await completeRitual(hotspotId: session.hotspot_id) }
            } else if hostDone || guestDone {
                statusMessage = "Waiting for partner to complete seal…"
            } else {
                statusMessage = "Draw your part of the seal!"
            }
        case .complete:
            statusMessage = "👻 Ghost contained together!"
        case .failed:
            statusMessage = "❌ Containment failed"
        }
    }

    // MARK: - Grant rewards + shared journal entry
    func completeRitual(hotspotId: UUID) async {
        guard let session else { return }
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { return }

        struct EncounterInsert: Encodable {
            let user_id: UUID
            let hotspot_id: UUID
            let outcome: String
            let rewards_json: RewardsJSON
        }

        struct RewardsJSON: Encodable {
            let xp: Int
            let coop: Bool
            let partner_id: String
        }

        let partnerId = isHost ? session.guest_id?.uuidString ?? "" : session.host_id.uuidString
        let xp = 150

        let insert = EncounterInsert(
            user_id: userId,
            hotspot_id: hotspotId,
            outcome: "captured",
            rewards_json: RewardsJSON(xp: xp, coop: true, partner_id: partnerId)
        )

        do {
            try await SupabaseManager.shared.client
                .from("encounters")
                .insert(insert)
                .execute()
            await advanceStatus(to: .complete)
            await PlayerInventory.shared.grantTotemIfNeeded(totemName: "Spirit Ward")
        } catch {
            ErrorLogger.shared.log(error, context: "CoopSessionManager.completeRitual")
            errorText = error.localizedDescription
        }
    }

    func cleanup() async {
        await realtimeChannel?.unsubscribe()
        session = nil
        statusMessage = "Waiting for partner…"
    }
}
//
//  CoopRitualView.swift
//  urbanghosthunters
//

import SwiftUI

struct CoopRitualView: View {
    let hotspot: Hotspot
    @State private var coop = CoopSessionManager.shared
    @State private var showJoinSheet = false
    @State private var joinSessionId = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GridPattern()
                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                .ignoresSafeArea()

            VStack(spacing: 24) {

                // Header
                VStack(spacing: 4) {
                    Text("CO-OP RITUAL")
                        .font(.caption).bold()
                        .foregroundStyle(.purple)
                        .tracking(3)
                    Text(hotspot.name)
                        .font(.title2).bold()
                        .foregroundStyle(.white)
                }
                .padding(.top, 40)

                // Status card
                VStack(spacing: 8) {
                    Text(coop.statusMessage)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if let error = coop.errorText {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.purple.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)

                // Session controls — shown when no session yet
                if coop.session == nil {
                    VStack(spacing: 12) {
                        Button {
                            Task { await coop.createSession(hotspotId: hotspot.id) }
                        } label: {
                            Label("Host Ritual", systemImage: "person.badge.plus")
                                .font(.headline).bold()
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            showJoinSheet = true
                        } label: {
                            Label("Join Ritual", systemImage: "person.2.fill")
                                .font(.headline).bold()
                                .foregroundStyle(.purple)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                }

                // Session info — shown when session exists
                if let session = coop.session {
                    VStack(spacing: 16) {
                        // Session ID to share with partner
                        if coop.isHost && CoopStatus(rawValue: session.status) == .waiting {
                            VStack(spacing: 6) {
                                Text("Share this code with your partner:")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                Text(session.id.uuidString.prefix(8).uppercased())
                                    .font(.title3).bold()
                                    .foregroundStyle(.purple)
                                    .monospaced()
                            }
                            .padding()
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                        }

                        // Heading alignment step
                        if CoopStatus(rawValue: session.status) == .heading {
                            VStack(spacing: 8) {
                                Text("HEADING ALIGNMENT")
                                    .font(.caption2).bold()
                                    .foregroundStyle(.white.opacity(0.5))
                                    .tracking(2)

                                HStack {
                                    VStack {
                                        Text("You")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.5))
                                        Text("\(Int(coop.isHost ? session.host_heading : session.guest_heading))°")
                                            .font(.title3).bold()
                                            .foregroundStyle(.purple)
                                    }
                                    Spacer()
                                    VStack {
                                        Text("Partner")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.5))
                                        Text("\(Int(coop.isHost ? session.guest_heading : session.host_heading))°")
                                            .font(.title3).bold()
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                                let diff = abs(session.host_heading - session.guest_heading)
                                let aligned = min(diff, 360 - diff) < 20
                                if aligned {
                                    Button {
                                        Task { await coop.advanceStatus(to: .luring) }
                                    } label: {
                                        Text("PROCEED TO LURE →")
                                            .font(.headline).bold()
                                            .foregroundStyle(.black)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(.purple)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Luring step
                        if CoopStatus(rawValue: session.status) == .luring {
                            VStack(spacing: 8) {
                                Text("Both players hold to lure simultaneously")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)

                                Button {
                                    Task { await coop.advanceStatus(to: .sealing) }
                                } label: {
                                    Text("PROCEED TO SEAL →")
                                        .font(.headline).bold()
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(.purple)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Sealing step
                        if CoopStatus(rawValue: session.status) == .sealing {
                            VStack(spacing: 8) {
                                Text("Draw your part of the seal")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))

                                CoopSealCanvas {
                                    Task { await coop.markSealComplete() }
                                }
                                .frame(height: 200)
                                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal)
                        }

                        // Complete/failed
                        if CoopStatus(rawValue: session.status) == .complete ||
                           CoopStatus(rawValue: session.status) == .failed {
                            Button {
                                Task {
                                    await coop.cleanup()
                                    dismiss()
                                }
                            } label: {
                                Text("FINISH")
                                    .font(.headline).bold()
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.purple)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                Spacer()

                Button {
                    Task {
                        await coop.cleanup()
                        dismiss()
                    }
                } label: {
                    Text("Cancel")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinSessionSheet { sessionId in
                Task { await coop.joinSession(sessionId: sessionId) }
            }
        }
        .onDisappear {
            Task { await coop.cleanup() }
        }
    }
}

// MARK: - Join Session Sheet
struct JoinSessionSheet: View {
    let onJoin: (UUID) -> Void
    @State private var code = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("JOIN RITUAL")
                .font(.headline).bold()
                .foregroundStyle(.white)
                .padding(.top, 24)

            Text("Enter the 8-character code from your partner")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            TextField("Enter code", text: $code)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .padding(.horizontal)

            Button {
                // Find session by short code
                Task {
                    let sessions: [CoopSession] = (try? await SupabaseManager.shared.client
                        .from("coop_sessions")
                        .select()
                        .eq("status", value: "waiting")
                        .execute()
                        .value) ?? []
                    if let match = sessions.first(where: {
                        $0.id.uuidString.prefix(8).uppercased() == code.uppercased()
                    }) {
                        onJoin(match.id)
                        dismiss()
                    }
                }
            } label: {
                Text("JOIN")
                    .font(.headline).bold()
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(code.count == 8 ? Color.purple : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(code.count != 8)
            .padding(.horizontal)

            Button("Cancel") { dismiss() }
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom)
        }
        .background(Color.black)
        .presentationDetents([.medium])
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
    let xp = 150 // co-op bonus XP

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

// MARK: - Coop Seal Canvas
struct CoopSealCanvas: View {
    let onComplete: () -> Void
    @State private var points: [SealPoint] = []
    @State private var submitted = false

    var body: some View {
        ZStack {
            Canvas { context, _ in
                guard points.count > 1 else { return }
                var path = Path()
                path.move(to: CGPoint(x: points[0].x, y: points[0].y))
                for point in points.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x, y: point.y))
                }
                context.stroke(path, with: .color(.purple), lineWidth: 3)
                context.stroke(path, with: .color(.purple.opacity(0.3)), lineWidth: 8)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !submitted else { return }
                        points.append(SealPoint(x: value.location.x, y: value.location.y))
                    }
                    .onEnded { _ in
                        guard !submitted, points.count > 20 else { return }
                        submitted = true
                        onComplete()
                    }
            )

            if submitted {
                Text("✅ Seal submitted")
                    .font(.caption).bold()
                    .foregroundStyle(.green)
            } else {
                Text("Draw here")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }
}
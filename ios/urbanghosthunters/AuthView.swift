//
//  AuthView.swift
//  urbanghosthunters
//
//  Created by Jarvis Akhigbe on 10/05/2026.
//

import SwiftUI
import Supabase

struct AuthView: View {
    @StateObject private var supa = SupabaseManager.shared
    @State private var email = ""
    @State private var otp = ""
    @State private var isWaitingForOTP = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Auth").font(.title2).bold()

            if let uid = supa.userId {
                Text("Signed in as:")
                Text(uid).font(.footnote).textSelection(.enabled)
            } else {
                Text("Not signed in").foregroundStyle(.secondary)
            }

            Divider()

            Button("Continue as Guest") {
                Task { await signInAnonymously() }
            }
            .buttonStyle(.borderedProminent)

            Divider()

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            if isWaitingForOTP {
                TextField("OTP code", text: $otp)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                Button("Verify OTP") {
                    Task { await verifyOTP() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Send OTP") {
                    Task { await sendOTP() }
                }
                .buttonStyle(.bordered)
            }

            if let errorText {
                Text(errorText).foregroundStyle(.red).font(.footnote)
            }

            Spacer()
        }
        .padding()
    }

    @MainActor
    private func signInAnonymously() async {
        do {
            errorText = nil
            _ = try await supa.client.auth.signInAnonymously()
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func sendOTP() async {
        do {
            errorText = nil
            try await supa.client.auth.signInWithOTP(email: email)
            isWaitingForOTP = true
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func verifyOTP() async {
        do {
            errorText = nil
            _ = try await supa.client.auth.verifyOTP(
                email: email,
                token: otp,
                type: .email
            )
        } catch {
            errorText = error.localizedDescription
        }
    }
}

//
//  AuthView.swift
//  urbanghosthunters
//
//  Created by Jarvis Akhigbe on 10/05/2026.
//

import SwiftUI
import Supabase
import Auth

struct AuthView: View {
    @StateObject private var supa = SupabaseManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Urban Ghost Hunter")
                .font(.title2).bold()

            if let uid = supa.userId {
                Text("Signed in as:")
                Text(uid).font(.footnote).textSelection(.enabled)
            } else {
                Text("Sign in to continue")
                    .foregroundStyle(.secondary)
            }

            Divider()

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Button(isLoading ? "Signing in..." : "Sign In") {
                Task { await signIn() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            Button("Create Account") {
                Task { await signUp() }
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)

            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Spacer()
        }
        .padding()
    }

    @MainActor
    private func signIn() async {
        isLoading = true
        errorText = nil
        do {
            _ = try await supa.client.auth.signIn(email: email, password: password)
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func signUp() async {
        isLoading = true
        errorText = nil
        do {
            _ = try await supa.client.auth.signUp(email: email, password: password)
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}

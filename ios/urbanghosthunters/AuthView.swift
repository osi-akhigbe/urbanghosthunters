//
//  AuthView.swift
//  urbanghosthunters
//

import SwiftUI
import Supabase

struct AuthView: View {
    @StateObject private var supa = SupabaseManager.shared
    @State private var email = ""
    @State private var otp = ""
    @State private var isWaitingForOTP = false
    @State private var errorText: String?
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            KitScreenBackground()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 44))
                            .foregroundStyle(Kit.Colors.accent)

                        Text("URBAN GHOST HUNTER")
                            .font(Kit.Font.module())
                            .foregroundStyle(Kit.Colors.accent)
                            .tracking(2)

                        Text("Field kit authentication")
                            .font(Kit.Font.body())
                            .foregroundStyle(Kit.Colors.label)
                    }
                    .padding(.top, 40)

                    if let uid = supa.userId {
                        KitPanel {
                            VStack(alignment: .leading, spacing: 8) {
                                KitSectionLabel(text: "OPERATOR ID")
                                Text(uid)
                                    .font(Kit.Font.label())
                                    .foregroundStyle(Kit.Colors.signal)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    KitPanel {
                        VStack(spacing: 16) {
                            KitPrimaryButton(title: "CONTINUE AS GUEST") {
                                Task { await signInAnonymously() }
                            }
                            .disabled(isSigningIn)

                            if isSigningIn {
                                KitLoadingView(message: "AUTHENTICATING…")
                            }
                        }
                    }

                    KitPanel {
                        VStack(spacing: 16) {
                            KitSectionLabel(text: "EMAIL ACCESS")

                            KitTextField(label: "EMAIL", text: $email, keyboard: .emailAddress)

                            if isWaitingForOTP {
                                KitTextField(label: "OTP CODE", text: $otp, keyboard: .numberPad)
                                KitPrimaryButton(title: "VERIFY OTP") {
                                    Task { await verifyOTP() }
                                }
                            } else {
                                KitPrimaryButton(title: "SEND OTP") {
                                    Task { await sendOTP() }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let errorText {
                        KitBanner(style: .error, title: "AUTH FAILED", message: errorText)
                    }
                }
                .padding(20)
            }
        }
        .kitScreen()
    }

    @MainActor
    private func signInAnonymously() async {
        isSigningIn = true
        defer { isSigningIn = false }
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

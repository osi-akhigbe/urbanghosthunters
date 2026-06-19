import SwiftUI
import Supabase

private enum AppPhase { case splash, permissions, app }

struct ContentView: View {
    @ObservedObject private var supa = SupabaseManager.shared
    @State private var phase: AppPhase = .splash
    @State private var authPassed = false  // tracks auth this session without signing out

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashView()
                    .transition(.opacity)
            case .permissions:
                PermissionsOnboardingView {
                    withAnimation(.easeInOut(duration: 0.8)) { phase = .app }
                }
                .transition(.opacity)
            case .app:
                if supa.isSignedIn && authPassed {
                    MainAppView()
                        .transition(.opacity)
                } else {
                    AuthView(onAuthenticated: {
                        withAnimation(.easeInOut(duration: 0.8)) { authPassed = true }
                    })
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.9), value: phase)
        .animation(.easeInOut(duration: 0.8), value: authPassed)
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { phase = .permissions }
        }
    }
}

// MARK: - Splash

struct SplashView: View {
    @State private var glowOpacity = 0.4
    @State private var scale = 0.85
    @State private var textOpacity = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GridPattern()
                .stroke(Color.purple.opacity(0.08), lineWidth: 1)
                .ignoresSafeArea()

            // 3D ghost floating behind the logo — non-AR, almost transparent
            GhostARView(proximityLevel: 0.75)
                .frame(width: 210, height: 290)
                .opacity(0.28)
                .allowsHitTesting(false)

            // Glow behind logo
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .opacity(glowOpacity)

            VStack(spacing: 20) {
                Image(systemName: "ghost.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .purple.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(scale)

                VStack(spacing: 4) {
                    Text("URBAN GHOST")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(6)

                    Text("HUNTERS")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(.purple)
                        .tracking(6)
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { scale = 1.0 }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.8
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.3)) { textOpacity = 1.0 }
        }
    }
}

// MARK: - Permissions onboarding

struct PermissionsOnboardingView: View {
    let onContinue: () -> Void
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            KitScreenBackground()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 52))
                        .foregroundStyle(Kit.Colors.accent)

                    Text("FIELD KIT ACCESS")
                        .font(Kit.Font.module())
                        .foregroundStyle(Kit.Colors.accent)
                        .tracking(2)

                    Text("Urban Ghost Hunters needs a few\npermissions to operate in the field.")
                        .font(Kit.Font.body())
                        .foregroundStyle(Kit.Colors.label)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 36)

                VStack(spacing: 10) {
                    PermissionRow(icon: "location.fill",
                                  title: "LOCATION",
                                  desc: "Detects nearby anomalies on the map")
                    PermissionRow(icon: "camera.fill",
                                  title: "CAMERA",
                                  desc: "Live AR view during containment")
                    PermissionRow(icon: "mic.fill",
                                  title: "MICROPHONE",
                                  desc: "Ghost lure — speak to attract spirits")
                    PermissionRow(icon: "bell.fill",
                                  title: "NOTIFICATIONS",
                                  desc: "Real-time anomaly alerts near you")
                }
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 12) {
                    if isRequesting {
                        KitLoadingView(message: "REQUESTING ACCESS…")
                            .padding(.bottom, 8)
                    }

                    KitPrimaryButton(title: "GRANT ACCESS", enabled: !isRequesting) {
                        isRequesting = true
                        Task {
                            await PermissionsManager.shared.requestAll()
                            onContinue()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        KitPanel {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Kit.Colors.accent)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Kit.Font.label())
                        .foregroundStyle(.white)
                        .tracking(Kit.Layout.labelTracking)
                    Text(desc)
                        .font(Kit.Font.body())
                        .foregroundStyle(Kit.Colors.muted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Kit.Colors.muted)
            }
        }
    }
}

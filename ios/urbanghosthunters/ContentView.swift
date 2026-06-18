import SwiftUI
import Supabase

struct ContentView: View {
    @ObservedObject private var supa = SupabaseManager.shared
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                if supa.isSignedIn {
                    MainAppView()
                        .transition(.opacity)
                } else {
                    AuthView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 1), value: showSplash)
        .task {
            try? await Task.sleep(for: .seconds(2))
            showSplash = false
        }
    }
}

struct SplashView: View {
    @State private var glowOpacity = 0.4
    @State private var scale = 0.85
    @State private var textOpacity = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Subtle grid background
            GridPattern()
                .stroke(Color.purple.opacity(0.08), lineWidth: 1)
                .ignoresSafeArea()

            // Glow behind logo
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .opacity(glowOpacity)

            VStack(spacing: 20) {
                // Replace "ghost.fill" with your actual logo asset if you have one
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
            withAnimation(.easeOut(duration: 0.7)) {
                scale = 1.0
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.8
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
                textOpacity = 1.0
            }
        }
    }
}
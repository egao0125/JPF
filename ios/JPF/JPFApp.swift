import SwiftUI

@main
struct JPFApp: App {
    @State private var session = SessionStore()
    @State private var justCompletedOnboarding = false
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false

    init() {
        #if DEBUG
        // UI-testing hook: inject an auth token via launch environment.
        if let token = ProcessInfo.processInfo.environment["JPF_DEBUG_TOKEN"] {
            APIClient.shared.token = token
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isBootstrapping {
                    SplashView()
                } else if session.user == nil {
                    if hasCompletedOnboarding {
                        // Straight to email entry right after onboarding; the welcome
                        // screen is only for returning logged-out users.
                        AuthFlowView(startAtEmail: justCompletedOnboarding)
                    } else {
                        OnboardingView {
                            hasCompletedOnboarding = true
                            justCompletedOnboarding = true
                        }
                    }
                } else {
                    MainTabView()
                }
            }
            .environment(session)
            .preferredColorScheme(.light)
            .tint(Theme.accent)
            .task { await session.bootstrap() }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.gradient)
        }
    }
}

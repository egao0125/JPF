import SwiftUI

@main
struct JPFApp: App {
    @State private var session = SessionStore()

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
                    AuthFlowView()
                } else {
                    MainTabView()
                }
            }
            .environment(session)
            .preferredColorScheme(.dark)
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

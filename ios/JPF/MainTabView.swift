import SwiftUI

struct MainTabView: View {
    @State private var unreadCount = 0

    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("フィード", systemImage: "house.fill") }

            NotificationsView(unreadCount: $unreadCount)
                .tabItem { Label("通知", systemImage: "bell.fill") }
                .badge(unreadCount)

            ProfileView()
                .tabItem { Label("マイページ", systemImage: "person.fill") }
        }
        .task { await refreshBadge() }
    }

    private func refreshBadge() async {
        if let response = try? await APIClient.shared.notifications() {
            unreadCount = response.unreadCount
        }
    }
}

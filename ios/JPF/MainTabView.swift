import SwiftUI

// Custom bottom bar with a raised center compose button, Sidechat-style.
struct MainTabView: View {
    private enum Tab { case feed, notifications, profile }

    @State private var tab: Tab = .feed
    @State private var unreadCount = 0
    @State private var showCompose = false
    @State private var feedModel = FeedModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .feed:
                    FeedView(model: feedModel)
                case .notifications:
                    NotificationsView(unreadCount: $unreadCount)
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task { await refreshBadge() }
        .sheet(isPresented: $showCompose) {
            ComposeView(channels: feedModel.channels) {
                Task { await feedModel.reload() }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            barButton(icon: "house.fill", label: "フィード", active: tab == .feed) { tab = .feed }
                .frame(maxWidth: .infinity)

            Button {
                showCompose = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Theme.accent)
                    .clipShape(Circle())
                    .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .offset(y: -14)
            .frame(maxWidth: .infinity)

            barButton(icon: "bell.fill", label: "通知", active: tab == .notifications, badge: unreadCount) {
                tab = .notifications
                Task { await refreshBadge() }
            }
            .frame(maxWidth: .infinity)

            barButton(icon: "person.fill", label: "マイページ", active: tab == .profile) { tab = .profile }
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
        .background(
            Theme.card
                .overlay(Rectangle().fill(Theme.cardBorder).frame(height: 0.5), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func barButton(
        icon: String,
        label: String,
        active: Bool,
        badge: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.title3)
                    if badge > 0 {
                        Text("\(min(badge, 99))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.error)
                            .clipShape(Capsule())
                            .offset(x: 10, y: -6)
                    }
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(active ? Theme.accent : Theme.secondaryText)
        }
        .buttonStyle(.plain)
    }

    private func refreshBadge() async {
        if let response = try? await APIClient.shared.notifications() {
            unreadCount = response.unreadCount
        }
    }
}

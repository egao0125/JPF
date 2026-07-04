import SwiftUI

// Bottom bar with 4 tabs; compose is an X-style floating button that
// sits above the bar on the feed tab.
struct MainTabView: View {
    private enum Tab { case feed, messages, notifications, profile }

    @State private var tab: Tab
    @State private var unreadNotifications = 0

    init() {
        var initialTab: Tab = .feed
        #if DEBUG
        // UI-testing hook: open a specific tab via launch environment.
        switch ProcessInfo.processInfo.environment["JPF_DEBUG_TAB"] {
        case "messages": initialTab = .messages
        case "notifications": initialTab = .notifications
        case "profile": initialTab = .profile
        default: break
        }
        #endif
        _tab = State(initialValue: initialTab)
    }
    @State private var unreadMessages = 0
    @State private var showCompose = false
    @State private var feedModel = FeedModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .feed:
                    FeedView(model: feedModel)
                case .messages:
                    MessagesView(unreadMessages: $unreadMessages)
                case .notifications:
                    NotificationsView(unreadCount: $unreadNotifications)
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if tab == .feed {
                composeFab
            }

            bottomBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task { await refreshBadges() }
        .sheet(isPresented: $showCompose) {
            ComposeView(channels: feedModel.channels) {
                Task { await feedModel.reload() }
            }
        }
    }

    // X-style floating compose button, bottom-right above the bar.
    private var composeFab: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showCompose = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(Theme.accent)
                        .clipShape(Circle())
                        .shadow(color: Theme.accent.opacity(0.4), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 18)
                .padding(.bottom, 78)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            barButton(icon: "house.fill", label: "フィード", active: tab == .feed) { tab = .feed }
                .frame(maxWidth: .infinity)
            barButton(icon: "bubble.left.and.bubble.right.fill", label: "メッセージ", active: tab == .messages, badge: unreadMessages) {
                tab = .messages
            }
            .frame(maxWidth: .infinity)
            barButton(icon: "bell.fill", label: "通知", active: tab == .notifications, badge: unreadNotifications) {
                tab = .notifications
                Task { await refreshBadges() }
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

    private func refreshBadges() async {
        async let notifications = try? APIClient.shared.notifications()
        async let conversations = try? APIClient.shared.conversations()
        if let response = await notifications { unreadNotifications = response.unreadCount }
        if let list = await conversations { unreadMessages = list.reduce(0) { $0 + $1.unreadCount } }
    }
}

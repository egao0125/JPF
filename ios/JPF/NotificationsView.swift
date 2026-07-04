import SwiftUI

struct NotificationsView: View {
    @Binding var unreadCount: Int

    @State private var notifications: [NotificationDto] = []
    @State private var isLoaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if notifications.isEmpty && isLoaded {
                            VStack(spacing: 10) {
                                Text("🔔")
                                    .font(.system(size: 48))
                                Text("通知はまだありません")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            .padding(48)
                        }
                        ForEach(notifications) { notification in
                            NavigationLink(value: notification.postId) {
                                row(notification)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                .refreshable { await load() }
            }
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { postId in
                PostDetailView(postId: postId)
            }
            .task {
                await load()
                await markRead()
            }
        }
    }

    private func row(_ notification: NotificationDto) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AliasAvatar(emoji: notification.actorEmoji, size: 34, colorKey: notification.actorAlias)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(notification.actorAlias)さん")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.text)
                + Text(" が\(notification.type == "reply_to_comment" ? "あなたのコメントに返信しました" : "あなたの投稿にコメントしました")")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                Text(notification.preview)
                    .font(.subheadline)
                    .foregroundStyle(Theme.text.opacity(0.85))
                    .lineLimit(2)
                Text(TimeAgo.string(from: notification.createdAt))
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            if !notification.isRead {
                Circle()
                    .fill(Theme.accentPink)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func load() async {
        if let response = try? await APIClient.shared.notifications() {
            notifications = response.notifications
            unreadCount = response.unreadCount
        }
        isLoaded = true
    }

    private func markRead() async {
        guard unreadCount > 0 else { return }
        try? await APIClient.shared.markNotificationsRead()
        unreadCount = 0
    }
}

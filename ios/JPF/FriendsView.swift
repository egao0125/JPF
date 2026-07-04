import SwiftUI

struct FriendsView: View {
    @State private var data: FriendsResponse?
    @State private var addUsername = ""
    @State private var message: String?
    @State private var messageIsError = false
    @State private var chatTarget: ChatTarget?

    struct ChatTarget: Identifiable, Hashable {
        let conversationId: String
        let friendName: String
        var id: String { conversationId }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    addCard

                    if let incoming = data?.incoming, !incoming.isEmpty {
                        section("届いた申請") {
                            ForEach(incoming) { request in
                                incomingRow(request)
                            }
                        }
                    }

                    section("フレンド") {
                        if data?.friends.isEmpty != false {
                            Text("まだフレンドがいません。ユーザーネームで追加してみよう")
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryText)
                                .padding(.vertical, 8)
                        }
                        ForEach(data?.friends ?? []) { friend in
                            friendRow(friend)
                        }
                    }

                    if let outgoing = data?.outgoing, !outgoing.isEmpty {
                        section("申請中") {
                            ForEach(outgoing) { request in
                                Text("@\(request.username ?? "unknown")")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText)
                                    .padding(.vertical, 6)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .refreshable { await load() }
        }
        .navigationTitle("フレンド")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $chatTarget) { target in
            ChatView(conversationId: target.conversationId, friendName: target.friendName)
        }
        .task { await load() }
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ユーザーネームで追加")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.text)
            HStack(spacing: 10) {
                TextField("username", text: $addUsername)
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Theme.pill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Button {
                    Task { await sendRequest() }
                } label: {
                    Text("申請")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Theme.accent.opacity(addUsername.isEmpty ? 0.35 : 1))
                        .clipShape(Capsule())
                }
                .disabled(addUsername.isEmpty)
            }
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(messageIsError ? Theme.error : Theme.accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.text)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func incomingRow(_ request: FriendRequestDto) -> some View {
        HStack {
            Text("@\(request.username ?? "unknown")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            Button("承認") {
                Task { await respond(request, action: "accept") }
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Theme.accent)
            .clipShape(Capsule())
            Button("拒否") {
                Task { await respond(request, action: "decline") }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.pill)
            .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private func friendRow(_ friend: FriendDto) -> some View {
        HStack(spacing: 10) {
            Text(String((friend.username ?? "?").prefix(1)).uppercased())
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Theme.avatarColor(for: friend.username ?? "?"))
                .clipShape(Circle())
            Text("@\(friend.username ?? "unknown")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            Button {
                Task { await openChat(friend) }
            } label: {
                Label("メッセージ", systemImage: "bubble.left")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.accent.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        data = try? await APIClient.shared.friends()
    }

    private func sendRequest() async {
        message = nil
        do {
            try await APIClient.shared.sendFriendRequest(username: addUsername.trimmingCharacters(in: .whitespaces))
            message = "申請を送りました"
            messageIsError = false
            addUsername = ""
            await load()
        } catch {
            message = error.localizedDescription
            messageIsError = true
        }
    }

    private func respond(_ request: FriendRequestDto, action: String) async {
        try? await APIClient.shared.respondFriendRequest(id: request.requestId, action: action)
        await load()
    }

    private func openChat(_ friend: FriendDto) async {
        if let result = try? await APIClient.shared.openConversation(with: friend.userId) {
            chatTarget = ChatTarget(conversationId: result.id, friendName: result.friend.username ?? "フレンド")
        }
    }
}

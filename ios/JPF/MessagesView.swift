import SwiftUI

struct MessagesView: View {
    @Binding var unreadMessages: Int

    @State private var conversations: [ConversationDto] = []
    @State private var isLoaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if conversations.isEmpty && isLoaded {
                            emptyState
                        }
                        ForEach(conversations) { conversation in
                            NavigationLink(value: conversation) {
                                row(conversation)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
                .refreshable { await load() }
            }
            .navigationTitle("メッセージ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ConversationDto.self) { conversation in
                ChatView(conversationId: conversation.id, friendName: conversation.friend.username ?? "フレンド")
            }
            .task { await load() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(Theme.secondaryText)
            Text("まだメッセージがありません")
                .font(.subheadline)
                .foregroundStyle(Theme.text)
            Text("マイページの「フレンド」から友達を追加して、\nチャットをはじめよう")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(40)
    }

    private func row(_ conversation: ConversationDto) -> some View {
        HStack(spacing: 12) {
            Text(String((conversation.friend.username ?? "?").prefix(1)).uppercased())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Theme.avatarColor(for: conversation.friend.username ?? "?").opacity(1))
                .overlay(Circle().stroke(Theme.cardBorder, lineWidth: 0.5))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("@\(conversation.friend.username ?? "unknown")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                if let last = conversation.lastMessage {
                    Text("\(last.isMine ? "自分: " : "")\(last.text)")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                if let last = conversation.lastMessage {
                    Text(TimeAgo.string(from: last.createdAt))
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.accent)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func load() async {
        if let list = try? await APIClient.shared.conversations() {
            conversations = list
            unreadMessages = list.reduce(0) { $0 + $1.unreadCount }
        }
        isLoaded = true
    }
}

struct ChatView: View {
    let conversationId: String
    let friendName: String

    @State private var messages: [MessageDto] = []
    @State private var draft = ""
    @State private var isSending = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messages) { message in
                                bubble(message)
                                    .id(message.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.last?.id) { _, lastId in
                        if let lastId {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                inputBar
            }
        }
        .navigationTitle("@\(friendName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            // Simple polling while the screen is open; cancelled on dismiss.
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func bubble(_ message: MessageDto) -> some View {
        HStack {
            if message.isMine { Spacer(minLength: 60) }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(message.isMine ? .white : Theme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.isMine ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.card))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(TimeAgo.string(from: message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 4)
            }
            if !message.isMine { Spacer(minLength: 60) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("メッセージを入力…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .focused($inputFocused)

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.accent.opacity(canSend ? 1 : 0.35))
                    .clipShape(Circle())
            }
            .disabled(!canSend || isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.background)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func load() async {
        if let page = try? await APIClient.shared.messages(conversationId: conversationId) {
            if page.messages != messages { messages = page.messages }
        }
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        if let message = try? await APIClient.shared.sendMessage(conversationId: conversationId, text: text) {
            messages.append(message)
            draft = ""
        }
    }
}

import SwiftUI
import Observation

enum FeedSort: String, CaseIterable, Identifiable {
    case new
    case hot
    case top

    var id: String { rawValue }
    var label: String {
        switch self {
        case .new: "新着"
        case .hot: "急上昇"
        case .top: "トップ"
        }
    }
}

@Observable
@MainActor
final class FeedModel {
    var posts: [PostDto] = []
    var channels: [ChannelDto] = []
    var sort: FeedSort = .hot
    var selectedChannel: String? // nil = all
    var isLoading = false
    var errorMessage: String?
    private var nextCursor: Int? = 0

    private let api = APIClient.shared

    func loadChannels() async {
        if channels.isEmpty {
            channels = (try? await api.channels()) ?? []
        }
    }

    func reload() async {
        nextCursor = 0
        await loadMore(reset: true)
    }

    func loadMore(reset: Bool = false) async {
        guard let cursor = nextCursor, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await api.feed(sort: sort.rawValue, channel: selectedChannel, cursor: cursor)
            posts = reset ? page.posts : posts + page.posts
            nextCursor = page.nextCursor
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current post: PostDto) async {
        guard post.id == posts.last?.id else { return }
        await loadMore()
    }

    // Optimistic vote with rollback on failure.
    func vote(post: PostDto, value: Int) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let newValue = post.myVote == value ? 0 : value
        let old = posts[index]
        posts[index].score += newValue - old.myVote
        posts[index].myVote = newValue
        do {
            let result = try await api.votePost(id: post.id, value: newValue)
            if let i = posts.firstIndex(where: { $0.id == post.id }) {
                posts[i].score = result.score
                posts[i].myVote = result.myVote
            }
        } catch {
            if let i = posts.firstIndex(where: { $0.id == post.id }) { posts[i] = old }
        }
    }

    func votePoll(post: PostDto, optionId: String) async {
        guard let poll = post.poll else { return }
        if let updated = try? await api.votePoll(pollId: poll.id, optionId: optionId),
           let i = posts.firstIndex(where: { $0.id == post.id }) {
            posts[i].poll = updated
        }
    }

    func applyDetailChanges(_ post: PostDto) {
        if let i = posts.firstIndex(where: { $0.id == post.id }) { posts[i] = post }
    }

    func remove(postId: String) {
        posts.removeAll { $0.id == postId }
    }
}

struct FeedView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = FeedModel()
    @State private var showCompose = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12, pinnedViews: []) {
                        sortPicker
                        channelChips
                        if let message = model.errorMessage, model.posts.isEmpty {
                            errorCard(message)
                        }
                        ForEach(model.posts) { post in
                            NavigationLink(value: post.id) {
                                PostCardView(
                                    post: post,
                                    onVote: { value in Task { await model.vote(post: post, value: value) } },
                                    onPollVote: { optionId in Task { await model.votePoll(post: post, optionId: optionId) } }
                                )
                            }
                            .buttonStyle(.plain)
                            .task { await model.loadMoreIfNeeded(current: post) }
                        }
                        if model.isLoading {
                            ProgressView().padding(24)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 80)
                }
                .refreshable { await model.reload() }

                composeButton
            }
            .navigationTitle(session.user?.school.shortName ?? session.user?.school.name ?? "JPF")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { postId in
                PostDetailView(postId: postId) { updated in
                    if let updated { model.applyDetailChanges(updated) } // nil = deleted
                } onDelete: {
                    model.remove(postId: postId)
                }
            }
            .task {
                await model.loadChannels()
                if model.posts.isEmpty { await model.reload() }
            }
            .sheet(isPresented: $showCompose) {
                ComposeView(channels: model.channels) {
                    Task { await model.reload() }
                }
            }
        }
    }

    private var sortPicker: some View {
        Picker("並び順", selection: Bindable(model).sort) {
            ForEach(FeedSort.allCases) { sort in
                Text(sort.label).tag(sort)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 8)
        .onChange(of: model.sort) { _, _ in
            Task { await model.reload() }
        }
    }

    private var channelChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "すべて", emoji: "🏛️", isSelected: model.selectedChannel == nil) {
                    model.selectedChannel = nil
                }
                ForEach(model.channels) { channel in
                    chip(
                        title: channel.nameJa,
                        emoji: channel.emoji,
                        isSelected: model.selectedChannel == channel.slug
                    ) {
                        model.selectedChannel = channel.slug
                    }
                }
            }
        }
    }

    private func chip(title: String, emoji: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Task { await model.reload() }
        } label: {
            Text("\(emoji) \(title)")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.card))
                .foregroundStyle(isSelected ? .white : Theme.secondaryText)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? .clear : Theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var composeButton: some View {
        Button {
            showCompose = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Theme.gradient)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
        .padding(20)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("⚠️ \(message)")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            Button("再読み込み") {
                Task { await model.reload() }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardStyle()
    }
}

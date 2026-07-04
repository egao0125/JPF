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
    private var nextCursor: String?
    private var reachedEnd = false

    private let api = APIClient.shared

    func loadChannels() async {
        if channels.isEmpty {
            channels = (try? await api.channels()) ?? []
        }
    }

    func reload() async {
        nextCursor = nil
        reachedEnd = false
        await loadMore(reset: true)
    }

    func loadMore(reset: Bool = false) async {
        guard !reachedEnd || reset, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await api.feed(
                sort: sort.rawValue,
                channel: selectedChannel,
                cursor: reset ? nil : nextCursor
            )
            posts = reset ? page.posts : posts + page.posts
            nextCursor = page.nextCursor
            reachedEnd = page.nextCursor == nil
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
    @Bindable var model: FeedModel

    var body: some View {
        NavigationStack {
            ZStack {
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
                    .padding(.bottom, 96)
                }
                .refreshable { await model.reload() }
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
        }
    }

    // Text-only sort pills, Sidechat-style.
    private var sortPicker: some View {
        HStack(spacing: 8) {
            ForEach(FeedSort.allCases) { sort in
                let isSelected = model.sort == sort
                Button {
                    guard model.sort != sort else { return }
                    model.sort = sort
                    Task { await model.reload() }
                } label: {
                    Text(sort.label)
                        .font(.subheadline.weight(isSelected ? .bold : .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(isSelected ? Theme.text : Theme.card)
                        .foregroundStyle(isSelected ? .white : Theme.secondaryText)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var channelChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "すべて", isSelected: model.selectedChannel == nil) {
                    model.selectedChannel = nil
                }
                ForEach(model.channels) { channel in
                    chip(
                        title: channel.nameJa,
                        isSelected: model.selectedChannel == channel.slug
                    ) {
                        model.selectedChannel = channel.slug
                    }
                }
            }
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Task { await model.reload() }
        } label: {
            Text(title)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(isSelected ? Theme.accent : Theme.card)
                .foregroundStyle(isSelected ? .white : Theme.secondaryText)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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

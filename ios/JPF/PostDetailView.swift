import SwiftUI

struct PostDetailView: View {
    let postId: String
    var onChange: (PostDto?) -> Void = { _ in }
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    @State private var post: PostDto?
    @State private var comments: [CommentDto] = []
    @State private var commentText = ""
    @State private var commentAnonymous = true
    @State private var replyTarget: CommentDto?
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var reportTarget: ReportTarget?
    @State private var showDeleteConfirm = false
    @FocusState private var composerFocused: Bool

    private let api = APIClient.shared

    struct ReportTarget: Identifiable {
        let type: String
        let targetId: String
        var id: String { targetId }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if let post {
                            PostCardView(
                                post: post,
                                isDetail: true,
                                onVote: { value in Task { await votePost(value) } },
                                onPollVote: { optionId in Task { await votePoll(optionId) } }
                            )
                            commentsSection
                        } else if errorMessage == nil {
                            ProgressView().padding(40).frame(maxWidth: .infinity)
                        }
                        if let errorMessage {
                            Text("⚠️ \(errorMessage)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(24)
                        }
                    }
                    .padding(16)
                }
                composer
            }
        }
        .navigationTitle("スレッド")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let post {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if post.isMine {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("投稿を削除", systemImage: "trash")
                            }
                        } else {
                            Button {
                                reportTarget = ReportTarget(type: "post", targetId: post.id)
                            } label: {
                                Label("通報する", systemImage: "flag")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .task { await load() }
        .confirmationDialog("通報理由を選んでください", isPresented: reportDialogBinding, titleVisibility: .visible) {
            if let target = reportTarget {
                ForEach(["スパム", "誹謗中傷", "不適切な内容", "その他"], id: \.self) { reason in
                    Button(reason) {
                        Task { await report(target: target, reason: reason) }
                    }
                }
            }
        }
        .alert("投稿を削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除する", role: .destructive) {
                Task { await deletePost() }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private var reportDialogBinding: Binding<Bool> {
        Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } })
    }

    // MARK: - Comments

    private var commentTree: [(comment: CommentDto, depth: Int)] {
        let byParent = Dictionary(grouping: comments.filter { $0.parentId != nil }, by: { $0.parentId! })
        var result: [(CommentDto, Int)] = []
        func walk(_ comment: CommentDto, depth: Int) {
            result.append((comment, depth))
            for child in byParent[comment.id] ?? [] {
                walk(child, depth: depth + 1)
            }
        }
        for root in comments.filter({ $0.parentId == nil }) {
            walk(root, depth: 0)
        }
        return result
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("コメント \(comments.count)件")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.text)
                .padding(16)

            if comments.isEmpty {
                Text("最初のコメントを書いてみよう")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
            }

            ForEach(Array(commentTree.enumerated()), id: \.element.comment.id) { index, entry in
                if index > 0 {
                    Divider().padding(.leading, 16)
                }
                CommentRowView(
                    comment: entry.comment,
                    depth: entry.depth,
                    onVote: { value in Task { await voteComment(entry.comment, value: value) } },
                    onReply: {
                        replyTarget = entry.comment
                        composerFocused = true
                    },
                    onReport: {
                        reportTarget = ReportTarget(type: "comment", targetId: entry.comment.id)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let replyTarget {
                HStack {
                    Text("↩︎ \(replyTarget.emoji) \(replyTarget.alias) に返信")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Button {
                        self.replyTarget = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .padding(.horizontal, 4)
            }
            HStack(spacing: 10) {
                // Identity toggle: random alias ↔ your username.
                Button {
                    if session.user?.username == nil {
                        errorMessage = "実名コメントにはマイページでユーザーネームの設定が必要です"
                    } else {
                        commentAnonymous.toggle()
                    }
                } label: {
                    Text(commentAnonymous ? "匿名" : "@\(session.user?.username ?? "")")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .foregroundStyle(commentAnonymous ? Theme.secondaryText : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(commentAnonymous ? Theme.pill : Theme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                TextField(commentAnonymous ? "匿名でコメント…" : "実名でコメント…", text: $commentText, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
                    .focused($composerFocused)

                Button {
                    Task { await sendComment() }
                } label: {
                    if isSending {
                        ProgressView().tint(.white)
                            .frame(width: 38, height: 38)
                            .background(Theme.gradient)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Theme.gradient.opacity(canSend ? 1 : 0.35))
                            .clipShape(Circle())
                    }
                }
                .disabled(!canSend || isSending)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.background)
    }

    private var canSend: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func load() async {
        do {
            let detail = try await api.postDetail(id: postId)
            post = detail.post
            comments = detail.comments
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func votePost(_ value: Int) async {
        guard var current = post else { return }
        let newValue = current.myVote == value ? 0 : value
        current.score += newValue - current.myVote
        current.myVote = newValue
        post = current
        if let result = try? await api.votePost(id: current.id, value: newValue) {
            post?.score = result.score
            post?.myVote = result.myVote
        }
        if let post { onChange(post) }
    }

    private func voteComment(_ comment: CommentDto, value: Int) async {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        let newValue = comment.myVote == value ? 0 : value
        comments[index].score += newValue - comment.myVote
        comments[index].myVote = newValue
        if let result = try? await api.voteComment(id: comment.id, value: newValue),
           let i = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[i].score = result.score
            comments[i].myVote = result.myVote
        }
    }

    private func votePoll(_ optionId: String) async {
        guard let poll = post?.poll else { return }
        if let updated = try? await api.votePoll(pollId: poll.id, optionId: optionId) {
            post?.poll = updated
            if let post { onChange(post) }
        }
    }

    private func sendComment() async {
        guard let post else { return }
        isSending = true
        defer { isSending = false }
        do {
            let comment = try await api.createComment(
                postId: post.id,
                text: commentText.trimmingCharacters(in: .whitespacesAndNewlines),
                parentId: replyTarget?.id,
                anonymous: commentAnonymous
            )
            comments.append(comment)
            commentText = ""
            replyTarget = nil
            composerFocused = false
            self.post?.commentCount += 1
            if let updated = self.post { onChange(updated) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func report(target: ReportTarget, reason: String) async {
        do {
            try await api.report(targetType: target.type, targetId: target.targetId, reason: reason)
        } catch {
            errorMessage = error.localizedDescription
        }
        reportTarget = nil
    }

    private func deletePost() async {
        guard let post else { return }
        do {
            try await api.deletePost(id: post.id)
            onChange(nil)
            onDelete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CommentRowView: View {
    let comment: CommentDto
    let depth: Int
    var onVote: (Int) -> Void
    var onReply: () -> Void
    var onReport: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if depth > 0 {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.cardBorder)
                    .frame(width: 2)
                    .padding(.leading, CGFloat(min(depth, 3) - 1) * 18)
            }
            if let name = comment.authorName {
                Text(String(name.prefix(1)).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Theme.avatarColor(for: name))
                    .clipShape(Circle())
            } else {
                AliasAvatar(emoji: comment.emoji, size: 28, colorKey: comment.alias)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(comment.authorName.map { "@\($0)" } ?? comment.alias)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(comment.authorName != nil ? Theme.accent : Theme.secondaryText)
                    if comment.isOp {
                        Text("主")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.accent.opacity(0.12))
                            .foregroundStyle(Theme.accent)
                            .clipShape(Capsule())
                    }
                    Text("・\(TimeAgo.string(from: comment.createdAt))")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    if !comment.isMine && !comment.isRemoved {
                        Menu {
                            Button { onReport() } label: { Label("通報する", systemImage: "flag") }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .padding(4)
                        }
                    }
                }
                Text(comment.text)
                    .font(.subheadline)
                    .foregroundStyle(comment.isRemoved ? Theme.secondaryText : Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !comment.isRemoved {
                    HStack(spacing: 16) {
                        Button("返信", action: onReply)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                        Spacer()
                        VoteControl(score: comment.score, myVote: comment.myVote, onVote: onVote)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

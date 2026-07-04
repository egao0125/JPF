import SwiftUI

struct ProfileView: View {
    @Environment(SessionStore.self) private var session

    @State private var myPosts: [PostDto] = []
    @State private var showLogoutConfirm = false
    @State private var showServerSettings = false
    @State private var showUsernameEditor = false
    @State private var usernameDraft = ""
    @State private var usernameError: String?
    @State private var serverURL = UserDefaults.standard.string(forKey: "api_base_url") ?? APIClient.defaultBaseURL

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        profileCard
                        friendsRow
                        myPostsSection
                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
                .refreshable {
                    await session.refresh()
                    await loadPosts()
                }
            }
            .navigationTitle("マイページ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showServerSettings = true
                        } label: {
                            Label("サーバー設定", systemImage: "server.rack")
                        }
                        Button(role: .destructive) {
                            showLogoutConfirm = true
                        } label: {
                            Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: String.self) { postId in
                PostDetailView(postId: postId) { updated in
                    if let updated, let i = myPosts.firstIndex(where: { $0.id == updated.id }) {
                        myPosts[i] = updated
                    }
                } onDelete: {
                    Task { await loadPosts() }
                }
            }
            .task { await loadPosts() }
            .alert("ログアウトしますか？", isPresented: $showLogoutConfirm) {
                Button("ログアウト", role: .destructive) { session.logout() }
                Button("キャンセル", role: .cancel) {}
            }
            .alert("APIサーバーURL", isPresented: $showServerSettings) {
                TextField("http://localhost:3000", text: $serverURL)
                Button("保存") {
                    UserDefaults.standard.set(serverURL, forKey: "api_base_url")
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("実機で使う場合は Mac のIPアドレスを指定してください")
            }
            .alert("ユーザーネーム", isPresented: $showUsernameEditor) {
                TextField("3〜20文字の英数字・_", text: $usernameDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("保存") {
                    Task { await saveUsername() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("実名投稿やフレンド申請で使われます。匿名投稿には表示されません")
            }
            .alert("エラー", isPresented: Binding(
                get: { usernameError != nil },
                set: { if !$0 { usernameError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(usernameError ?? "")
            }
        }
    }

    private var profileCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.gradient)
                .frame(width: 80, height: 80)
                .background(Theme.gradient.opacity(0.15))
                .clipShape(Circle())

            VStack(spacing: 4) {
                Text(session.user?.school.name ?? "")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Text(session.user?.email ?? "")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                if session.user?.isModerator == true {
                    Text("モデレーター")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }

            Button {
                usernameDraft = session.user?.username ?? ""
                showUsernameEditor = true
            } label: {
                HStack(spacing: 6) {
                    if let username = session.user?.username {
                        Text("@\(username)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    } else {
                        Text("ユーザーネームを設定")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Theme.accent.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                stat(value: session.user?.karma ?? 0, label: "カルマ")
                divider
                stat(value: session.user?.postCount ?? 0, label: "投稿")
                divider
                stat(value: session.user?.commentCount ?? 0, label: "コメント")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var friendsRow: some View {
        NavigationLink {
            FriendsView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.body)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36)
                    .background(Theme.accent.opacity(0.1))
                    .clipShape(Circle())
                Text("フレンド")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func saveUsername() async {
        do {
            let me = try await APIClient.shared.setUsername(usernameDraft.trimmingCharacters(in: .whitespaces))
            session.user = me
        } catch {
            usernameError = error.localizedDescription
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.cardBorder)
            .frame(width: 1, height: 32)
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.gradient)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var myPostsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自分の投稿")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.text)

            if myPosts.isEmpty {
                Text("まだ投稿がありません。フィードから最初の投稿をしてみよう！")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .cardStyle()
            }

            ForEach(myPosts) { post in
                NavigationLink(value: post.id) {
                    PostCardView(post: post, onVote: { _ in }, onPollVote: { _ in })
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadPosts() async {
        myPosts = (try? await APIClient.shared.myPosts()) ?? []
    }
}

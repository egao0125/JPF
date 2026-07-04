import SwiftUI

struct ProfileView: View {
    @Environment(SessionStore.self) private var session

    @State private var myPosts: [PostDto] = []
    @State private var showLogoutConfirm = false
    @State private var showServerSettings = false
    @State private var serverURL = UserDefaults.standard.string(forKey: "api_base_url") ?? APIClient.defaultBaseURL

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        profileCard
                        myPostsSection
                    }
                    .padding(16)
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
                    Text("🛡️ モデレーター")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }

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

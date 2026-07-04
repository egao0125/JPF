import SwiftUI

// First-launch intro: what JPF is, how anonymity works, and the community
// guidelines the user agrees to before signing up.
struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var page: Int

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        var initialPage = 0
        #if DEBUG
        // UI-testing hook: jump to a specific page via launch environment.
        if let raw = ProcessInfo.processInfo.environment["JPF_DEBUG_ONBOARDING_PAGE"],
           let value = Int(raw) {
            initialPage = value
        }
        #endif
        _page = State(initialValue: initialPage)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < 2 {
                        Button("スキップ") {
                            withAnimation { page = 2 }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.trailing, 20)
                    }
                }
                .frame(height: 44)

                TabView(selection: $page) {
                    introPage(
                        icon: "graduationcap.fill",
                        title: "あなたの大学だけの空間",
                        body: "大学メール（.ac.jp）で在学を確認。\nフィードに流れるのは、同じキャンパスの\n学生の投稿だけ。"
                    )
                    .tag(0)

                    introPage(
                        icon: "theatermasks.fill",
                        title: "投稿はすべて匿名",
                        body: "名前もプロフィールも表示されません。\nスレッドごとにランダムな名前がつくから、\n本音で話せる。"
                    )
                    .tag(1)

                    guidelinesPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.bottom, 20)

                Button {
                    if page < 2 {
                        withAnimation { page += 1 }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(page < 2 ? "次へ" : "同意してはじめる")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 24)

                if page == 2 {
                    Text("タップすると、コミュニティガイドラインに同意したことになります")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 10)
                } else {
                    Spacer().frame(height: 25)
                }

                Spacer().frame(height: 24)
            }
        }
    }

    private func introPage(icon: String, title: String, body text: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(Theme.text)
                .frame(width: 140, height: 140)
                .background(Circle().fill(Theme.cardBorder.opacity(0.35)))
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.text)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var guidelinesPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.text)
                .frame(width: 140, height: 140)
                .background(Circle().fill(Theme.cardBorder.opacity(0.35)))
            Text("安心して使えるコミュニティに")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.text)

            VStack(alignment: .leading, spacing: 14) {
                guidelineRow(icon: "xmark.circle.fill", text: "誹謗中傷・個人の特定につながる投稿は禁止")
                guidelineRow(icon: "flag.fill", text: "通報が3件集まった投稿は自動的に非表示")
                guidelineRow(icon: "hand.raised.fill", text: "違反を繰り返すアカウントは利用停止")
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func guidelineRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.text)
                .frame(width: 24)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Capsule()
                    .fill(index == page ? Theme.text : Theme.cardBorder)
                    .frame(width: index == page ? 24 : 8, height: 8)
                    .animation(.easeOut(duration: 0.2), value: page)
            }
        }
    }
}

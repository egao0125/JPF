import SwiftUI

struct AuthFlowView: View {
    @Environment(SessionStore.self) private var session

    private enum Step { case welcome, email, code }

    @State private var step: Step
    @State private var email = ""
    @State private var code = ""
    @State private var devCodeHint: String?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @FocusState private var focused: Bool

    init(startAtEmail: Bool = false) {
        _step = State(initialValue: startAtEmail ? .email : .welcome)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                header
                Spacer()
                content
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.error)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                Spacer()
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.gradient)
            Text("JPF")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.gradient)
            Text("あなたのキャンパスの、本音の場所。\n大学メールで認証、投稿はすべて匿名。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            Button {
                step = .email
            } label: {
                Text("大学メールではじめる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.gradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

        case .email:
            VStack(spacing: 16) {
                TextField("you@u-tokyo.ac.jp", text: $email)
                    .textFieldStyle(JPFFieldStyle())
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit { Task { await sendCode() } }
                primaryButton("認証コードを送る", disabled: !email.contains("@")) {
                    await sendCode()
                }
            }
            .onAppear { focused = true }

        case .code:
            VStack(spacing: 16) {
                Text("\(email) に届いた6桁のコードを入力")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                if let devCodeHint {
                    Text("開発モード: コードは \(devCodeHint)")
                        .font(.footnote.monospaced())
                        .foregroundStyle(Theme.accent)
                }
                TextField("123456", text: $code)
                    .textFieldStyle(JPFFieldStyle())
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focused)
                    .onSubmit { Task { await verify() } }
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.filter(\.isNumber).prefix(6))
                    }
                primaryButton("ログイン", disabled: code.count != 6) {
                    await verify()
                }
                Button("メールアドレスを変更") {
                    step = .email
                    code = ""
                    errorMessage = nil
                }
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            }
            .onAppear { focused = true }
        }
    }

    private func primaryButton(_ title: String, disabled: Bool, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.gradient.opacity(disabled ? 0.35 : 1))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(disabled || isLoading)
    }

    private func sendCode() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.requestCode(email: email.trimmingCharacters(in: .whitespaces))
            devCodeHint = response.devCode
            step = .code
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func verify() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.verify(
                email: email.trimmingCharacters(in: .whitespaces),
                code: code
            )
            await session.login(token: response.token, user: response.user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct JPFFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.body)
            .padding(16)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
    }
}

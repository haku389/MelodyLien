import SwiftUI
import AuthenticationServices
import CryptoKit

/// アカウント連携 / ログイン（方式A）。
/// - 連携: 今のゲスト（匿名）アカウントにメール＋パスワードを設定して永続化（機種変更・再インストールに対応）。
/// - ログイン: 既存メールアカウントでサインインし、進行を復元。
struct AccountLinkView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    private enum Mode: String, CaseIterable { case link = "連携する", login = "ログイン" }
    @State private var mode: Mode = .link
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false
    @State private var currentNonce: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Text(mode == .link
                         ? "今の進行を保ったまま、メールとパスワードを設定します。機種変更や再インストール後も復元できます。"
                         : "登録済みのメールでログインし、進行を復元します。")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color(hex: "7B6F8A"))

                    VStack(spacing: 10) {
                        TextField("メールアドレス", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color(hex: "F5F0FF"), in: RoundedRectangle(cornerRadius: 12))
                        SecureField("パスワード（6文字以上）", text: $password)
                            .textContentType(.password)
                            .padding(12)
                            .background(Color(hex: "F5F0FF"), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if let error {
                        Text(error).font(.system(size: 11, weight: .heavy)).foregroundStyle(.red)
                    }

                    Button {
                        submit()
                    } label: {
                        Text(busy ? "処理中…" : (mode == .link ? "連携する" : "ログイン"))
                            .buttonLabel(.primary)
                    }
                    .disabled(busy || email.isEmpty || password.count < 6)

                    HStack {
                        Rectangle().fill(Color(hex: "E0D8F7")).frame(height: 1)
                        Text("または").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "B8ACD6"))
                        Rectangle().fill(Color(hex: "E0D8F7")).frame(height: 1)
                    }

                    SignInWithAppleButton(.signIn) { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        handleApple(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 46)

                    providerButton(title: "Google で続ける", bg: "FFFFFF", fg: "1c1c22", border: "E0D8F7") {
                        await vm.signInWithGoogle()
                    }
                    providerButton(title: "Spotify で続ける", bg: "1DB954", fg: "FFFFFF", border: "1DB954") {
                        await vm.signInWithSpotify()
                    }

                    Spacer(minLength: 8)
                }
                .padding(20)
            }
            .background(Color(hex: "FFFFFF").ignoresSafeArea())
            .navigationTitle("アカウント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        error = nil
        busy = true
        Task {
            let result = mode == .link
                ? await vm.linkAccount(email: email, password: password)
                : await vm.signInAccount(email: email, password: password)
            busy = false
            if let result {
                error = result
            } else {
                dismiss()
            }
        }
    }

    /// Google / Spotify など OAuth プロバイダ用のボタン。
    private func providerButton(title: String, bg: String, fg: String, border: String,
                                _ action: @escaping () async -> String?) -> some View {
        Button {
            error = nil; busy = true
            Task {
                let err = await action()
                busy = false
                if let err { error = err } else { dismiss() }
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color(hex: fg))
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Color(hex: bg), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: border)))
        }
        .disabled(busy)
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                error = "Apple サインインの情報を取得できませんでした"
                return
            }
            error = nil
            Task {
                if let err = await vm.signInWithApple(idToken: idToken, nonce: nonce) {
                    error = err
                } else {
                    dismiss()
                }
            }
        case .failure:
            error = "Apple サインインがキャンセルされました"
        }
    }

    // MARK: - Nonce（Sign in with Apple ⇄ Supabase の検証用）

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count { result.append(charset[Int(random)]); remaining -= 1 }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

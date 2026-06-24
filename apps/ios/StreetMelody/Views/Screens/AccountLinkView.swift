import SwiftUI

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
}

import SwiftUI

struct AccountSheet: View {
    @ObservedObject var session: AccountSession
    @Binding var isPresented: Bool

    @State private var mode: Mode = .login
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    enum Mode { case login, signup }

    var body: some View {
        VStack(spacing: 18) {
            Text(mode == .login ? "Log In" : "Sign Up")
                .font(.title2.bold())

            Picker("", selection: $mode) {
                Text("Log In").tag(Mode.login)
                Text("Sign Up").tag(Mode.signup)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            VStack(spacing: 10) {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(width: 260)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(width: 260)
            }

            Button(action: submit) {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text(mode == .login ? "Log In" : "Create Account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(width: 260)
            .disabled(username.isEmpty || password.isEmpty || isLoading)

            Button("Cancel") { isPresented = false }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 340)
    }

    func submit() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let token: String
                if mode == .login {
                    token = try await AccountAPI.login(username: username, password: password)
                } else {
                    token = try await AccountAPI.signup(username: username, password: password)
                }
                await MainActor.run {
                    session.setSession(username: username, token: token)
                    isLoading = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

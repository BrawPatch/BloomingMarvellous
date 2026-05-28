#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - LoginView
//
// Minimal username/password form that wraps AuthService.login. On success
// invokes `onSuccess(UserModel)` so the app's root view can swap in the
// authenticated experience. The auth token is persisted to Keychain by
// AuthService before this view's callback fires, so subsequent
// NetworkService calls auto-attach the Bearer header.
public struct LoginView: View {

    // MARK: - Dependencies
    private let auth: AuthServiceProtocol
    private let onSuccess: (UserModel) -> Void

    // MARK: - Form state
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    @FocusState private var focused: Field?

    private enum Field { case username, password }

    public init(auth: AuthServiceProtocol = AuthService(),
                onSuccess: @escaping (UserModel) -> Void) {
        self.auth = auth
        self.onSuccess = onSuccess
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .focused($focused, equals: .username)
                        .onSubmit { focused = .password }

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focused, equals: .password)
                        .onSubmit { Task { await submit() } }
                } header: {
                    Text("Sign in to Blooming Marvellous")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isSubmitting { ProgressView() }
                            Text(isSubmitting ? "Signing in…" : "Sign in")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { focused = .username }
        }
    }

    // MARK: - Submission

    private var canSubmit: Bool {
        !isSubmitting && !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    @MainActor
    private func submit() async {
        guard canSubmit else { return }
        focused = nil
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let user = try await auth.login(username: username, pass: password)
            onSuccess(user)
        } catch {
            // Surface a short, non-sensitive message. Real error stays in os_log
            // via AuthService's logger; we never echo the raw password back.
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let net = error as? NetworkError {
            switch net {
            case .httpError(let code) where code == 401:
                return "Incorrect username or password."
            case .unauthorized:
                return "Incorrect username or password."
            case .httpError(let code):
                return "Server error (\(code)). Try again in a moment."
            case .invalidURL, .noData, .decodingError, .unknown:
                return "Couldn't reach the server. Check your connection and try again."
            }
        }
        return "Sign in failed. Try again."
    }
}

// MARK: - Preview
#Preview {
    LoginView { _ in }
}
#endif

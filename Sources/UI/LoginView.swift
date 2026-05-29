#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - LoginView (BMFinal-styled)

public struct LoginView: View {

    private let auth: AuthServiceProtocol
    private let onSuccess: (UserModel) -> Void

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var showingSignUp: Bool = false
    @FocusState private var focused: Field?

    private enum Field { case username, password }

    public init(auth: AuthServiceProtocol = AuthService(),
                onSuccess: @escaping (UserModel) -> Void) {
        self.auth = auth
        self.onSuccess = onSuccess
    }

    public var body: some View {
        ZStack {
            Color.bmBg.ignoresSafeArea()

            // Subtle corner decorations to match the BMFinal aesthetic
            decorations

            VStack(spacing: 20) {
                Spacer(minLength: 24)

                titleCard

                VStack(spacing: 14) {
                    bmField("Username",
                            text: $username,
                            isSecure: false,
                            field: .username,
                            submitLabel: .next)

                    bmField("Password",
                            text: $password,
                            isSecure: true,
                            field: .password,
                            submitLabel: .go)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.custom("Nunito-SemiBold", size: 12))
                            .foregroundStyle(Color.bmRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting { ProgressView().tint(.white) }
                            Text(isSubmitting ? "Signing in…" : "Sign in")
                                .font(.custom("Fredoka-SemiBold", size: 16))
                                .foregroundStyle(.white)
                                .kerning(0.5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSubmit ? Color.bmGreen : Color.bmGreenMid)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.bmGreen.opacity(0.25), radius: 6, y: 2)
                    }
                    .disabled(!canSubmit)
                }
                .padding(20)
                .bmCard()
                .padding(.horizontal, 24)

                Button {
                    showingSignUp = true
                } label: {
                    HStack(spacing: 4) {
                        Text("New to Blooming Marvellous?")
                            .font(.custom("Nunito-SemiBold", size: 12))
                            .foregroundStyle(Color.bmText2)
                        Text("Create account")
                            .font(.custom("Fredoka-SemiBold", size: 12))
                            .foregroundStyle(Color.bmGreen)
                    }
                }

                Spacer()
            }
        }
        .onAppear { focused = .username }
        .sheet(isPresented: $showingSignUp) { SignUpView() }
    }

    // MARK: - Title card

    private var titleCard: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("Blooming ")
                    .font(.custom("Fredoka-Bold", size: 30))
                    .foregroundStyle(Color.bmLilac)
                Text("Marvellous")
                    .font(.custom("Fredoka-Bold", size: 30))
                    .foregroundStyle(Color.bmPeach)
            }
            Text("Bloom-based Garden Planner")
                .font(.custom("Nunito-SemiBold", size: 13))
                .foregroundStyle(Color.bmText2)
                .kerning(0.3)
        }
        .stickerCard(radius: 20)
        .padding(.horizontal, 24)
    }

    // MARK: - Form field helper

    @ViewBuilder
    private func bmField(_ placeholder: String,
                         text: Binding<String>,
                         isSecure: Bool,
                         field: Field,
                         submitLabel: SubmitLabel) -> some View {
        HStack {
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                        .textContentType(.password)
                } else {
                    TextField(placeholder, text: text)
                        .textContentType(.username)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                }
            }
            .font(.custom("Nunito-SemiBold", size: 15))
            .foregroundStyle(Color.bmText1)
            .focused($focused, equals: field)
            .submitLabel(submitLabel)
            .onSubmit {
                if field == .username { focused = .password }
                else { Task { await submit() } }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.bmBgSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(focused == field ? Color.bmBorderAct : Color.bmBorder, lineWidth: 1.5))
    }

    // MARK: - Decorations

    private var decorations: some View {
        GeometryReader { geo in
            Group {
                FlowerView(size: 56, petalColor: .bmFlowerPink, centerColor: .bmLilac)
                    .rotationEffect(.degrees(-12))
                    .position(x: 40, y: 80)
                    .opacity(0.55)
                FlowerView(size: 38, petalColor: .bmLilac, centerColor: .bmAmber)
                    .rotationEffect(.degrees(20))
                    .position(x: geo.size.width - 42, y: 120)
                    .opacity(0.5)
                LeafView(size: 34, color: .bmLeafSage)
                    .rotationEffect(.degrees(20))
                    .position(x: 30, y: geo.size.height - 80)
                    .opacity(0.4)
                LeafView(size: 26, color: .bmLeafSage)
                    .rotationEffect(.degrees(-30))
                    .position(x: geo.size.width - 36, y: geo.size.height - 60)
                    .opacity(0.4)
            }
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
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let net = error as? NetworkError {
            switch net {
            case .unauthorized:
                return "Incorrect username or password."
            case .httpError(let code) where code == 401:
                return "Incorrect username or password."
            case .httpError(let code):
                return "Server error (\(code)). Try again in a moment."
            case .invalidURL, .noData, .decodingError, .unknown:
                return "Couldn't reach the server."
            }
        }
        return "Sign in failed. Try again."
    }
}

#Preview {
    LoginView { _ in }
}
#endif

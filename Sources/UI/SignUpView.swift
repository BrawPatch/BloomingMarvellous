#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - SignUpView (BMFinal-styled)
//
// Wireframe: Splash/Login → Create account. Captures username + password +
// first name. Self-serve account creation is not yet exposed by the
// backend (no /v1/auth/register), so submit surfaces a "Coming soon"
// banner explaining provisioning is done via scripts/create-user.mjs.
// The UI itself is wireframe-complete so the journey is explorable.

public struct SignUpView: View {

    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var firstName: String = ""
    @State private var username:  String = ""
    @State private var password:  String = ""
    @State private var confirm:   String = ""
    @State private var status:    Status = .editing
    @FocusState private var focused: Field?

    private enum Field { case firstName, username, password, confirm }
    private enum Status: Equatable {
        case editing
        case submitting
        case unavailable
        case validation(String)
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.bmBg.ignoresSafeArea()
                decorations

                ScrollView {
                    VStack(spacing: 18) {
                        titleCard

                        formCard

                        if case .unavailable = status {
                            unavailableBanner
                        }
                    }
                    .padding(.vertical, 18)
                }
            }
            .bmNavTitle("Create account", icon: "🌱")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.bmText2)
                }
            }
            .onAppear { focused = .firstName }
        }
    }

    private var titleCard: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("Blooming ")
                    .font(.custom("Fredoka-Bold", size: 24))
                    .foregroundStyle(Color.bmLilac)
                Text("Marvellous")
                    .font(.custom("Fredoka-Bold", size: 24))
                    .foregroundStyle(Color.bmPeach)
            }
            Text("Join the garden")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
        }
        .stickerCard(radius: 18)
        .padding(.horizontal, 24)
    }

    private var formCard: some View {
        VStack(spacing: 14) {
            bmField("First name", text: $firstName, isSecure: false, field: .firstName, submit: .next)
            bmField("Username",   text: $username,  isSecure: false, field: .username,  submit: .next)
            bmField("Password",   text: $password,  isSecure: true,  field: .password,  submit: .next)
            bmField("Confirm password", text: $confirm, isSecure: true, field: .confirm, submit: .go)

            if case .validation(let msg) = status {
                Text(msg)
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { submit() } label: {
                HStack(spacing: 8) {
                    if status == .submitting { ProgressView().tint(.white) }
                    Text(status == .submitting ? "Creating…" : "Create account")
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
    }

    private var unavailableBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "envelope.badge")
                    .foregroundStyle(Color.bmAmber)
                Text("Self-serve sign-up isn't open yet")
                    .font(.custom("Fredoka-SemiBold", size: 13))
                    .foregroundStyle(Color.bmText1)
            }
            Text("During the beta, accounts are provisioned by the team. Ask an admin to run scripts/create-user.mjs, then sign in.")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bmBgSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.bmAmber.opacity(0.6), lineWidth: 1.5))
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func bmField(_ placeholder: String,
                         text: Binding<String>,
                         isSecure: Bool,
                         field: Field,
                         submit: SubmitLabel) -> some View {
        HStack {
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                        .textContentType(field == .password ? .newPassword : .newPassword)
                } else {
                    TextField(placeholder, text: text)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(field == .firstName ? .words : .never)
                }
            }
            .font(.custom("Nunito-SemiBold", size: 15))
            .foregroundStyle(Color.bmText1)
            .focused($focused, equals: field)
            .submitLabel(submit)
            .onSubmit(advance)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.bmBgSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(focused == field ? Color.bmBorderAct : Color.bmBorder, lineWidth: 1.5))
    }

    private var decorations: some View {
        GeometryReader { geo in
            Group {
                FlowerView(size: 50, petalColor: .bmFlowerPink, centerColor: .bmLilac)
                    .rotationEffect(.degrees(-15))
                    .position(x: 44, y: 90)
                    .opacity(0.45)
                FlowerView(size: 34, petalColor: .bmLilac, centerColor: .bmAmber)
                    .rotationEffect(.degrees(18))
                    .position(x: geo.size.width - 42, y: 110)
                    .opacity(0.45)
                LeafView(size: 28, color: .bmLeafSage)
                    .rotationEffect(.degrees(25))
                    .position(x: geo.size.width - 32, y: geo.size.height - 60)
                    .opacity(0.35)
            }
        }
        .allowsHitTesting(false)
    }

    private var canSubmit: Bool {
        guard status != .submitting else { return false }
        return !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !confirm.isEmpty
    }

    private func advance() {
        switch focused {
        case .firstName: focused = .username
        case .username:  focused = .password
        case .password:  focused = .confirm
        case .confirm:   submit()
        case .none:      break
        }
    }

    private func submit() {
        guard canSubmit else { return }
        focused = nil
        if password.count < 8 {
            status = .validation("Password must be at least 8 characters.")
            return
        }
        if password != confirm {
            status = .validation("Passwords don't match.")
            return
        }
        status = .submitting
        // TODO: when /v1/auth/register lands, swap this delay for a real
        // AuthService.register(...) call. Until then we surface a banner
        // explaining provisioning happens via scripts/create-user.mjs.
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            await MainActor.run { status = .unavailable }
        }
    }
}
#endif

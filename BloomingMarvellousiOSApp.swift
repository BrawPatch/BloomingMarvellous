import SwiftUI
import BloomingMarvellous
import BloomingMarvellousUI

@main
struct BloomingMarvellousiOSApp: App {

    private let auth: AuthService
    @State private var session: UserModel?

    init() {
        BMFonts.register()
        let auth = AuthService()
        self.auth = auth

        // BM_AUTO_LOGIN — XCUITest / preview-only bypass. When the launch
        // env var is set to "1" we skip the login screen and seed a mock
        // Pro UserModel so the screenshot tour can navigate the rest of
        // the app without typing credentials. Never set in release builds.
        let env = ProcessInfo.processInfo.environment
        let autoLogin = env["BM_AUTO_LOGIN"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-BM_AUTO_LOGIN")

        if autoLogin {
            self._session = State(initialValue: UserModel(
                userId: 99_999,
                firstName: env["BM_AUTO_LOGIN_NAME"] ?? "Chance",
                apiToken: "",
                tier: .pro,
                purchasedPacks: ContentPack.allCases))
        } else if auth.hasStoredToken() {
            // We have a token but no UserModel cached on disk yet — synthesise a
            // minimal one so the home view can render. The next /home or /data
            // call will surface a 401 if the token is stale, and the UI will
            // route the user back to login.
            self._session = State(initialValue: UserModel(userId: 0,
                                                          firstName: "Gardener",
                                                          apiToken: "",
                                                          tier: .pro,
                                                          purchasedPacks: ContentPack.allCases))
        } else {
            self._session = State(initialValue: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let user = session {
                MainTabView(user: user) {
                    try? auth.logout()
                    session = nil
                }
            } else {
                LoginView(auth: auth) { user in
                    session = user
                }
            }
        }
    }
}

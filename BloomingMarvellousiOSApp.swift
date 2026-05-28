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
        if auth.hasStoredToken() {
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
                HomeView(user: user) {
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

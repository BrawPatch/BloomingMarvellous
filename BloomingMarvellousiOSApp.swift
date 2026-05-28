import SwiftUI
import BloomingMarvellous
import BloomingMarvellousUI

struct HomeControllerHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> HomeViewController {
        HomeViewController()
    }

    func updateUIViewController(_ uiViewController: HomeViewController, context: Context) { }
}

@main
struct BloomingMarvellousiOSApp: App {

    private let auth: AuthService
    @State private var isAuthenticated: Bool

    init() {
        let auth = AuthService()
        self.auth = auth
        self._isAuthenticated = State(initialValue: auth.hasStoredToken())
    }

    var body: some Scene {
        WindowGroup {
            if isAuthenticated {
                HomeControllerHost()
                    .ignoresSafeArea(.container, edges: .bottom)
            } else {
                LoginView(auth: auth) { _ in
                    isAuthenticated = true
                }
            }
        }
    }
}

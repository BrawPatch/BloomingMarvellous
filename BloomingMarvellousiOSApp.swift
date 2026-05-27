import SwiftUI
import BloomingMarvellousUI

struct HomeControllerHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> HomeViewController {
        HomeViewController()
    }

    func updateUIViewController(_ uiViewController: HomeViewController, context: Context) { }
}

@main
struct BloomingMarvellousiOSApp: App {
    var body: some Scene {
        WindowGroup {
            HomeControllerHost()
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

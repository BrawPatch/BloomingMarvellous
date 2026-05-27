import SwiftUI
import BloomingMarvellousUI

#if canImport(UIKit)
import UIKit

private struct HomeControllerHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> HomeViewController {
        return HomeViewController()
    }

    func updateUIViewController(_ uiViewController: HomeViewController, context: Context) { }
}
#elseif canImport(AppKit)
import AppKit

private struct HomeControllerHost: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> HomeViewController {
        return HomeViewController()
    }

    func updateNSViewController(_ nsViewController: HomeViewController, context: Context) { }
}
#endif

@main
struct BloomingMarvellousDemoApp: App {
    var body: some Scene {
        WindowGroup {
            HomeControllerHost()
                .frame(minWidth: 420, minHeight: 420)
        }
    }
}

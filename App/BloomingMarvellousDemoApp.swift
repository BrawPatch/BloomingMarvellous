import SwiftUI
import BloomingMarvellous
import BloomingMarvellousUI

#if canImport(UIKit)

// On iOS the demo app renders the real SwiftUI HomeView with a stub
// pro-tier UserModel. There's no login flow in the demo — it's purely a
// preview surface for the design system and content fetch.
@main
struct BloomingMarvellousDemoApp: App {
    init() { BMFonts.register() }

    var body: some Scene {
        WindowGroup {
            HomeView(user: UserModel(userId: 0,
                                     firstName: "Gardener",
                                     apiToken: "",
                                     tier: .pro,
                                     purchasedPacks: ContentPack.allCases)) { }
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

#else

// macOS demo target — the iOS-only HomeView/LoginView aren't available,
// so we render a small placeholder using only cross-platform primitives.
@main
struct BloomingMarvellousDemoApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("Blooming Marvellous")
                    .font(.title)
                    .bold()
                Text("Demo target — open the iOS scheme to see the redesigned UI.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .frame(minWidth: 420, minHeight: 240)
        }
    }
}

#endif

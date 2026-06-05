#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - MainTabView
//
// Authenticated root. The bottom bar now carries just three tabs:
// Home, Wishlist and My plants. Plants (search) and Planting (schedule)
// were removed from the bar — both already have dedicated home tiles
// ("Pick your plants" / "Planting Schedule"), and the home tiles now
// push their destinations via NavigationLink so the back button works
// naturally.

public struct MainTabView: View {

    @StateObject private var store: GardenStore
    @StateObject private var library: LibraryStore
    private let user: UserModel
    private let onLogout: () -> Void
    @State private var selection: AppTab = .home
    /// Bumped every time the user taps the Home tab (including re-taps
    /// while already on Home). HomeView observes this token and uses it
    /// to dismiss any open sheets / popovers / pushed screens so the
    /// gardener gets a clean dashboard view every time.
    @State private var homeResetToken: Int = 0
    /// Splash gate. True once the user has tapped through SplashView's
    /// "Enter the garden" CTA. Stays in @State (not @AppStorage) so the
    /// splash + Pro CTA shows every session — matches the brief.
    @State private var splashCompleted: Bool = false
    @State private var showingStore: Bool = false

    @MainActor
    public init(user: UserModel, onLogout: @escaping () -> Void) {
        self.user = user

        // No "My First Garden" auto-seed any more — the SetupView wizard
        // is the canonical first-run experience. BM_AUTO_LOGIN is the one
        // exception: pre-seed a demo garden + bed so the screenshot tour
        // doesn't have to walk the wizard.
        let store = GardenStore(user: user, seedFirstGarden: false)
        let isAutoLogin = ProcessInfo.processInfo.environment["BM_AUTO_LOGIN"] == "1"
        if isAutoLogin && !store.hasCompletedSetup {
            let g = Garden(name: "Demo Garden",
                           soilType: .loam,
                           wetness: .normalWell,
                           exposure: .normal,
                           sunlight: .sunnyAlways)
            store.addGarden(g)
            store.selectedGardenId = g.id
            store.addBed(Bed(gardenId: g.id, name: "Bed 1",
                             widthCm: 120, lengthCm: 240, status: .active))
            store.postcode = "EH3"
        }

        self._store   = StateObject(wrappedValue: store)
        self._library = StateObject(wrappedValue: LibraryStore())
        self.onLogout = onLogout
    }

    public var body: some View {
        Group {
            if !splashCompleted {
                SplashView(user: user,
                           onContinue: { splashCompleted = true },
                           onUpgrade: { showingStore = true },
                           onBuyPack: { _ in showingStore = true })
                    .environmentObject(library)
            } else if store.hasCompletedSetup {
                tabsBody
            } else {
                SetupView()
                    .environmentObject(store)
                    .environmentObject(library)
            }
        }
        .task { await library.loadIfNeeded() }
        .sheet(isPresented: $showingStore) {
            StoreSheet()
        }
    }

    private var tabsBody: some View {
        // Intercept every selection change. When the gardener taps the
        // Home tab — whether they were on another tab or already on Home
        // — we bump `homeResetToken` so HomeView can dismiss any sheets
        // or pop any pushed screens. Mirrors the standard "tap a tab to
        // pop to root" iOS pattern.
        let selectionBinding = Binding<AppTab>(
            get: { selection },
            set: { newValue in
                if newValue == .home { homeResetToken &+= 1 }
                selection = newValue
            }
        )
        return TabView(selection: selectionBinding) {
            NavigationStack {
                HomeView(user: user,
                         onLogout: onLogout,
                         onSelectTab: { selection = $0 },
                         resetToken: homeResetToken)
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            NavigationStack {
                PlantWishlistView()
            }
            .tabItem { Label("Wishlist", systemImage: "heart.fill") }
            .tag(AppTab.wishlist)

            NavigationStack {
                MyCurrentPlantsView()
            }
            .tabItem { Label("My plants", systemImage: "leaf.fill") }
            .tag(AppTab.myPlants)
        }
        .tint(Color.bmGreen)
        .environmentObject(store)
        .environmentObject(library)
    }
}

// Cases kept for back-compat with home tile actions even when the tab
// itself no longer exists on the bar (HomeView pushes the screen via a
// NavigationLink in that case).
public enum AppTab: Hashable {
    case home, soil, picker, bloom, planting, wishlist, myPlants
}
#endif

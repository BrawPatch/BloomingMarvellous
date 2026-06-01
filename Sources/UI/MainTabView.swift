#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - MainTabView
//
// Authenticated root. Hosts:
//   - 4 bottom tabs from the wireframe (Soil, Plant Picker, Bloom, Planting)
//   - A shared GardenStore exposed via @StateObject and an .environmentObject
//     so every tab + push + sheet sees the same state.
//   - A header overlay on tab 0 (Home dashboard) reached via the synthesised
//     "Home" landing card; the 4 functional tabs are at the bottom.
//
// This keeps the tab bar identical to the wireframe while letting Home,
// Settings, Tasks, Manage Gardens etc. live above it.

public struct MainTabView: View {

    @StateObject private var store: GardenStore
    @StateObject private var library: LibraryStore
    private let user: UserModel
    private let onLogout: () -> Void
    @State private var selection: AppTab = .home

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
            if store.hasCompletedSetup {
                tabsBody
            } else {
                SetupView()
                    .environmentObject(store)
                    .environmentObject(library)
            }
        }
        .task { await library.loadIfNeeded() }
    }

    private var tabsBody: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeView(user: user,
                         onLogout: onLogout,
                         onSelectTab: { selection = $0 })
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            NavigationStack {
                SoilView()
            }
            .tabItem { Label("Soil", systemImage: "leaf.fill") }
            .tag(AppTab.soil)

            NavigationStack {
                PlantPickerMonthView()
            }
            .tabItem { Label("Plants", systemImage: "magnifyingglass") }
            .tag(AppTab.picker)

            NavigationStack {
                BloomScheduleView()
            }
            .tabItem { Label("Bloom", systemImage: "sparkles") }
            .tag(AppTab.bloom)

            NavigationStack {
                PlantingScheduleView()
            }
            .tabItem { Label("Planting", systemImage: "calendar") }
            .tag(AppTab.planting)
        }
        .tint(Color.bmGreen)
        .environmentObject(store)
        .environmentObject(library)
    }
}

public enum AppTab: Hashable {
    case home, soil, picker, bloom, planting
}
#endif

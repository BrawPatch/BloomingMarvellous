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
        self._store   = StateObject(wrappedValue: GardenStore(user: user))
        self._library = StateObject(wrappedValue: LibraryStore())
        self.onLogout = onLogout
    }

    public var body: some View {
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
        .task { await library.loadIfNeeded() }
    }
}

public enum AppTab: Hashable {
    case home, soil, picker, bloom, planting
}
#endif

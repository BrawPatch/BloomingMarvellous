#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - PlantWishlistView
//
// Bottom-tab destination listing every plant the gardener has heart-
// toggled across the picker, the browse tree, plant detail, or any
// other gallery surface. Rows use the shared PlantListRow so the
// thumbnail + common + Latin + type chip are consistent with the
// My Plants screen.
//
// Tapping a row pushes the existing PlantDetailView, which is exactly
// the "links to the plant detail page" behaviour the brief asked for.

public struct PlantWishlistView: View {

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if wishlistedPlants.isEmpty {
                    emptyState
                } else {
                    HStack(spacing: 6) {
                        SectionLabel("My wishlist", icon: "💚")
                        Spacer()
                        Text("\(wishlistedPlants.count) plant\(wishlistedPlants.count == 1 ? "" : "s")")
                            .font(.custom("Nunito-Bold", size: 11))
                            .foregroundStyle(Color.bmText3)
                    }
                    LazyVStack(spacing: 8) {
                        ForEach(wishlistedPlants) { plant in
                            NavigationLink {
                                PlantDetailView(plantId: plant.id)
                                    .environmentObject(store)
                                    .environmentObject(library)
                            } label: {
                                PlantListRow(plant: plant) {
                                    HeartToggle(plantId: plant.id)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .bmFloralBackdrop()
        .bmNavTitle("Wishlist", icon: "💚")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ContextualHelpButton(topic: .plantPicker)
            }
        }
    }

    private var wishlistedPlants: [Plant] {
        store.wishlistedIds
            .compactMap { library.plant(id: $0) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing on the wishlist yet.")
                .font(.custom("Fredoka-SemiBold", size: 15))
                .foregroundStyle(Color.bmText1)
            Text("Tap the heart on any plant tile or the Plant Detail screen to save it here. The heart turns red so you can see at a glance what you've picked.")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }
}
#endif

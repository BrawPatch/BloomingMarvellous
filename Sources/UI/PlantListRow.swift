#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - PlantListRow
//
// Single-row row used by My Plants and Wishlist screens. Includes the
// four pieces of info the screens promise: thumbnail, common name,
// Latin binomial, type chip — plus an optional trailing element so
// callers can drop a heart toggle or chevron in place.

struct PlantListRow<Trailing: View>: View {
    let plant: Plant
    let trailing: () -> Trailing

    init(plant: Plant, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.plant = plant
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            BMPlantImage(plant: plant, height: 56, cornerRadius: 10)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name)
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundStyle(Color.bmText1)
                    .lineLimit(1)
                Text(plant.latin)
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
                    .italic()
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(PlantGroup.group(for: plant).emoji)
                        .font(.system(size: 10))
                    Text(plant.type.label)
                        .font(.custom("Fredoka-SemiBold", size: 9))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(typeColour(plant))
                        .clipShape(Capsule())
                }
            }
            Spacer()
            trailing()
        }
        .padding(10)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.bmBorder, lineWidth: 1))
    }

    private func typeColour(_ plant: Plant) -> Color {
        switch PlantGroup.group(for: plant) {
        case .flower:    return .bmLilac
        case .vegetable: return .bmGreen
        case .herb:      return .bmGreenMid
        case .fruit:     return .bmPeach
        }
    }
}

// MARK: - HeartToggle
//
// Small heart button used as the trailing element on PlantListRow and
// as a corner overlay on the gallery's plant tiles. Toggles
// `GardenStore.wishlistedIds`.

struct HeartToggle: View {
    let plantId: String
    @EnvironmentObject private var store: GardenStore

    var body: some View {
        Button {
            store.toggleWishlist(plantId)
        } label: {
            Image(systemName: store.isWishlisted(plantId) ? "heart.fill" : "heart")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(store.isWishlisted(plantId) ? Color.bmRed : Color.bmText3)
                .padding(8)
                .background(Circle().fill(Color.white.opacity(0.92)))
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.isWishlisted(plantId) ? "Remove from wishlist" : "Add to wishlist")
    }
}
#endif

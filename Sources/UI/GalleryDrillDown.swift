#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - Gallery drill-down helpers
//
// The Matched / All Plants gallery used to render every cultivar as its own
// tile, which meant a month with 30+ marigold cultivars filled the screen.
// These views break the gallery into a three-level hierarchy:
//
//   PlantPickerGalleryView (per month + type group)
//     └─ genus tiles ("Begonias", "Marigolds", "Pelargoniums")
//        └─ species tiles ("Wax Begonia", "Tuberous Begonia")
//           └─ cultivar grid (the existing PlantPickerGalleryView.tile)
//
// Each level preserves the gardener's free-text search and filters because
// the parent passes the already-filtered Plant list down.

// MARK: - Genus tile

struct GalleryGenusTile: View {
    let label: String           // "Begonia" — singular common name
    let plants: [Plant]
    var body: some View {
        let rep = plants.first(where: { $0.imageUrl != nil }) ?? plants.first!
        let uniqueSeries = Set(plants.map { GalleryDrillDown.seriesLabel(plant: $0) }).count
        VStack(alignment: .leading, spacing: 6) {
            BMPlantImage(plant: rep, height: 96, cornerRadius: 12)
            Text(GalleryDrillDown.pluralise(label))
                .font(.custom("Nunito-Bold", size: 14))
                .foregroundStyle(Color.bmText1)
                .lineLimit(1)
            Text("\(uniqueSeries) species · \(plants.count) cultivar\(plants.count == 1 ? "" : "s")")
                .font(.custom("Nunito-SemiBold", size: 10))
                .foregroundStyle(Color.bmText3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.bmBorder, lineWidth: 1.5))
    }
}

// MARK: - Genus detail screen (level 2)
//
// Lists species buckets inside a genus. Each species tile pushes a
// cultivar grid. When a species has no cultivars (single plant), the
// tile pushes straight to its PlantDetailView.

struct GalleryGenusDetailView: View {
    let genusLabel: String
    let plants: [Plant]
    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    SectionLabel(GalleryDrillDown.pluralise(genusLabel), icon: "🌷")
                    Spacer()
                    Text("\(speciesBuckets.count) species")
                        .font(.custom("Nunito-Bold", size: 11))
                        .foregroundStyle(Color.bmText3)
                }
                LazyVStack(spacing: 10) {
                    ForEach(speciesBuckets, id: \.label) { bucket in
                        NavigationLink {
                            GallerySpeciesDetailView(speciesLabel: bucket.label,
                                                     plants: bucket.plants)
                                .environmentObject(store)
                                .environmentObject(library)
                        } label: {
                            speciesRow(bucket: bucket)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .bmFloralBackdrop()
        .bmNavTitle(GalleryDrillDown.pluralise(genusLabel), icon: "🌷")
    }

    private var speciesBuckets: [GalleryDrillDown.SpeciesBucket] {
        GalleryDrillDown.speciesBuckets(plants: plants)
    }

    private func speciesRow(bucket: GalleryDrillDown.SpeciesBucket) -> some View {
        let rep = bucket.plants.first(where: { $0.imageUrl != nil }) ?? bucket.plants.first!
        return HStack(spacing: 12) {
            BMPlantImage(plant: rep, height: 60, cornerRadius: 10)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(bucket.label)
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundStyle(Color.bmText1)
                    .lineLimit(1)
                Text("\(bucket.plants.count) cultivar\(bucket.plants.count == 1 ? "" : "s")")
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.bmText3)
        }
        .padding(10)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bmBorder, lineWidth: 1))
    }
}

// MARK: - Species detail screen (level 3)
//
// Grid of cultivar tiles, identical look to the previous flat gallery
// tile so the leaf experience is unchanged from what the gardener
// already knew.

struct GallerySpeciesDetailView: View {
    let speciesLabel: String
    let plants: [Plant]
    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(speciesLabel)
                        .font(.custom("Fredoka-SemiBold", size: 16))
                        .foregroundStyle(Color.bmText1)
                    Spacer()
                    Text("\(plants.count) cultivar\(plants.count == 1 ? "" : "s")")
                        .font(.custom("Nunito-Bold", size: 11))
                        .foregroundStyle(Color.bmText3)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                          spacing: 12) {
                    ForEach(plants.sorted { $0.name < $1.name }) { plant in
                        NavigationLink {
                            PlantDetailView(plantId: plant.id)
                                .environmentObject(store)
                                .environmentObject(library)
                        } label: {
                            GalleryDrillDown.cultivarTile(plant: plant)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .bmFloralBackdrop()
        .bmNavTitle(speciesLabel, icon: "🌸")
    }
}

// MARK: - Shared helpers

public enum GalleryDrillDown {

    public struct GenusBucket {
        public let label: String         // Singular common name root, e.g. "Begonia"
        public let plants: [Plant]
    }

    public struct SpeciesBucket {
        public let label: String         // Series label, e.g. "Wax Begonia"
        public let plants: [Plant]
    }

    /// Group a filtered set of plants by genus label (the last word of
    /// `seriesLabel`, e.g. "Begonia", "Marigold", "Petunia"). Sorted by
    /// count descending so the most populous tile appears first.
    public static func genusBuckets(plants: [Plant]) -> [GenusBucket] {
        let byLabel = Dictionary(grouping: plants) { genusLabel(plant: $0) }
        return byLabel
            .map { GenusBucket(label: $0.key, plants: $0.value) }
            .sorted { (a, b) in
                if a.plants.count != b.plants.count {
                    return a.plants.count > b.plants.count
                }
                return a.label < b.label
            }
    }

    /// "French Marigold 'Boy Spry'" → "French Marigold". "Petunia
    /// 'Surfinia Purple'" → "Petunia". A species without a cultivar
    /// suffix returns its full common name. Public version moved here
    /// from `PlantPickerGalleryView` so the drill-down screens can
    /// share it.
    public static func seriesLabel(plant: Plant) -> String {
        let name = plant.name
        if let r = name.range(of: " '") ?? name.range(of: " ‘") {
            return String(name[..<r.lowerBound])
        }
        return name
    }

    /// Group within a genus by species label (the full `seriesLabel`
    /// before the cultivar epithet — e.g. "Wax Begonia", "French
    /// Marigold", "Ivy-leaved Pelargonium").
    public static func speciesBuckets(plants: [Plant]) -> [SpeciesBucket] {
        let bySeries = Dictionary(grouping: plants) {
            GalleryDrillDown.seriesLabel(plant: $0)
        }
        return bySeries
            .map { SpeciesBucket(label: $0.key, plants: $0.value) }
            .sorted { (a, b) in
                if a.plants.count != b.plants.count {
                    return a.plants.count > b.plants.count
                }
                return a.label < b.label
            }
    }

    /// The genus's friendly common name root, derived from the plant's
    /// own common name. "French Marigold 'Boy'" → "Marigold"; "Wax
    /// Begonia 'Cocktail'" → "Begonia"; "Petunia 'Surfinia'" → "Petunia".
    /// Falls back to the Latin genus when the common name is just the
    /// binomial.
    public static func genusLabel(plant: Plant) -> String {
        let series = GalleryDrillDown.seriesLabel(plant: plant)
        if let last = series.split(separator: " ").last {
            let candidate = String(last)
            // If the candidate looks like a species epithet (lowercase
            // start) the common name is probably "Genus species" with
            // no friendlier alternative. Use the Latin genus instead.
            if let first = candidate.first, first.isLowercase {
                return plant.latin.split(separator: " ").first.map(String.init) ?? series
            }
            return candidate
        }
        return series
    }

    public static func pluralise(_ singular: String) -> String {
        let lower = singular.lowercased()
        if lower.hasSuffix("s") || lower.hasSuffix("z") { return singular }
        if lower.hasSuffix("y"),
           let beforeLast = singular.dropLast().last,
           !"aeiou".contains(beforeLast.lowercased()) {
            return String(singular.dropLast()) + "ies"
        }
        return singular + "s"
    }

    @ViewBuilder
    public static func cultivarTile(plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BMPlantImage(plant: plant, height: 96, cornerRadius: 12)
            Text(plant.name)
                .font(.custom("Nunito-Bold", size: 14))
                .foregroundStyle(Color.bmText1)
                .lineLimit(1)
            HStack(spacing: 4) {
                if let hex = plant.colorHex {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                }
                if let h = plant.heightCm {
                    Text("\(h) cm")
                        .font(.custom("Nunito-Bold", size: 10))
                        .foregroundStyle(Color.bmText3)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.bmSky.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(10)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.bmBorder, lineWidth: 1.5))
    }
}
#endif

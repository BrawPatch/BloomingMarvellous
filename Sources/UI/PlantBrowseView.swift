#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - PlantBrowseView
//
// Taxonomic drill-down through the plant library, so the gardener can
// pick a category (Flowers / Vegetables / Herbs / Fruit), then a genus
// (e.g. "Rosa (54)"), then a species (e.g. "Rosa rugosa"), then a
// cultivar grid. Replaces the 16,000-thumbnail wall the user would
// otherwise face on the Plant Picker.
//
// All four levels are NavigationLinks so the system back button works
// naturally. The picker tab bar sits ABOVE this view in PlantPicker
// MonthView's body, so swapping back to Matched/All mode pops us out.

public struct PlantBrowseView: View {

    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var store: GardenStore

    public init() {}

    public var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                SectionLabel("Browse by category", icon: "🌿")
                Tooltip("Pick a category, then a genus, then a species. Cultivars live at the leaves. Counts on each row tell you how many entries you'll find one level down.")
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                ForEach(PlantGroup.allCases) { group in
                    NavigationLink {
                        BrowseGenusListView(group: group)
                            .environmentObject(library)
                            .environmentObject(store)
                    } label: {
                        groupTile(group: group)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func groupTile(group: PlantGroup) -> some View {
        let count = library.plants.filter { PlantGroup.group(for: $0) == group }.count
        return VStack(alignment: .leading, spacing: 8) {
            Text(group.emoji)
                .font(.system(size: 32))
            Text(group.label)
                .font(.custom("Fredoka-SemiBold", size: 16))
                .foregroundStyle(Color.bmText1)
            Text("\(count) plant\(count == 1 ? "" : "s")")
                .font(.custom("Nunito-SemiBold", size: 11))
                .foregroundStyle(Color.bmText3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.bmBorder, lineWidth: 1.5))
    }
}

// MARK: - Genus list (level 2)

struct BrowseGenusListView: View {

    let group: PlantGroup
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var store: GardenStore
    @State private var search: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                PlantSearchBar(text: $search,
                               placeholder: "Search \(group.label.lowercased())")
                    .padding(.horizontal, 16)
                LazyVStack(spacing: 8) {
                    ForEach(filteredGenera, id: \.genus) { entry in
                        NavigationLink {
                            BrowseSpeciesListView(group: group, genus: entry.genus)
                                .environmentObject(library)
                                .environmentObject(store)
                        } label: {
                            genusRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                    if filteredGenera.isEmpty {
                        Text("Nothing matches.")
                            .font(.custom("Nunito-SemiBold", size: 12))
                            .foregroundStyle(Color.bmText3)
                            .padding(.top, 30)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 14)
        }
        .bmFloralBackdrop()
        .bmNavTitle(group.label, icon: group.emoji)
    }

    private struct GenusEntry {
        let genus: String
        let count: Int
        let representativePlant: Plant
    }

    private var filteredGenera: [GenusEntry] {
        let plants = library.plants.filter { PlantGroup.group(for: $0) == group }
        let byGenus = Dictionary(grouping: plants) { p in
            p.latin.split(separator: " ").first.map(String.init) ?? p.latin
        }
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let entries: [GenusEntry] = byGenus.compactMap { genus, list in
            guard let rep = list.first else { return nil }
            if !needle.isEmpty,
               !genus.lowercased().contains(needle),
               !(rep.name.lowercased().contains(needle)) {
                return nil
            }
            return GenusEntry(genus: genus, count: list.count, representativePlant: rep)
        }
        return entries.sorted { a, b in
            if a.count != b.count { return a.count > b.count }
            return a.genus < b.genus
        }
    }

    private func genusRow(entry: GenusEntry) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: entry.representativePlant.colorHex ?? "#a8d8bc"))
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.genus)
                    .font(.custom("Fredoka-SemiBold", size: 15))
                    .foregroundStyle(Color.bmText1)
                Text(genusCommonName(entry: entry))
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }
            Spacer()
            Text("\(entry.count)")
                .font(.custom("Nunito-Bold", size: 13))
                .foregroundStyle(Color.bmText2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.bmBgSoft)
                .clipShape(Capsule())
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.bmText3)
        }
        .padding(12)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.bmBorder, lineWidth: 1))
    }

    private func genusCommonName(entry: GenusEntry) -> String {
        // Pluck the representative plant's common name if it isn't just
        // the Latin binomial. Falls back to "various" when the genus
        // header has no friendly label to show.
        let rep = entry.representativePlant
        if rep.name.lowercased() == rep.latin.lowercased() { return "various" }
        // Strip the species epithet / cultivar suffix.
        return rep.name.split(separator: " ").first.map(String.init) ?? "various"
    }
}

// MARK: - Species list (level 3)

struct BrowseSpeciesListView: View {

    let group: PlantGroup
    let genus: String
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var store: GardenStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(speciesEntries, id: \.species) { entry in
                    NavigationLink {
                        BrowseCultivarGridView(species: entry.species,
                                               speciesName: entry.commonName,
                                               cultivars: entry.cultivars)
                            .environmentObject(library)
                            .environmentObject(store)
                    } label: {
                        speciesRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
                if speciesEntries.isEmpty {
                    Text("No species in this genus.")
                        .font(.custom("Nunito-SemiBold", size: 12))
                        .foregroundStyle(Color.bmText3)
                        .padding(.top, 30)
                }
            }
            .padding(16)
        }
        .bmFloralBackdrop()
        .bmNavTitle(genus, icon: "🌷")
    }

    private struct SpeciesEntry {
        let species: String       // Latin binomial e.g. "Rosa rugosa"
        let commonName: String
        let parent: Plant         // species record (or a cultivar that stands in)
        let cultivars: [Plant]    // cultivar entries belonging to this species
    }

    private var speciesEntries: [SpeciesEntry] {
        let plants = library.plants.filter { p in
            PlantGroup.group(for: p) == group &&
            (p.latin.split(separator: " ").first.map(String.init) ?? "") == genus
        }
        // Group by species binomial — strip cultivar epithet (the bit in
        // single quotes / curly quotes).
        let byBinomial = Dictionary(grouping: plants) { p -> String in
            let stripped = p.latin.replacingOccurrences(
                of: #"\s+[‘'"][^'’"]+[’'"]\s*$"#,
                with: "",
                options: .regularExpression
            )
            return stripped
        }
        return byBinomial.compactMap { binomial, list in
            // Prefer the canonical species record if present.
            let parent = list.first { $0.latin == binomial } ?? list.first!
            let cultivars = list.filter { $0.latin != binomial }
            return SpeciesEntry(
                species: binomial,
                commonName: parent.name,
                parent: parent,
                cultivars: cultivars
            )
        }
        .sorted { a, b in
            if a.cultivars.count != b.cultivars.count {
                return a.cultivars.count > b.cultivars.count
            }
            return a.species < b.species
        }
    }

    private func speciesRow(entry: SpeciesEntry) -> some View {
        HStack(spacing: 12) {
            BMPlantImage(plant: entry.parent, height: 56, cornerRadius: 10)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.commonName)
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundStyle(Color.bmText1)
                    .lineLimit(1)
                Text(entry.species)
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
                    .italic()
                    .lineLimit(1)
                if entry.cultivars.count > 0 {
                    Text("\(entry.cultivars.count) cultivar\(entry.cultivars.count == 1 ? "" : "s") available")
                        .font(.custom("Nunito-Bold", size: 10))
                        .foregroundStyle(Color.bmGreen)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.bmText3)
        }
        .padding(10)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.bmBorder, lineWidth: 1))
    }
}

// MARK: - Cultivar grid (level 4 — leaf)

struct BrowseCultivarGridView: View {

    let species: String
    let speciesName: String
    let cultivars: [Plant]
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var store: GardenStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let parent = library.plant(id: species.lowercased().replacingOccurrences(of: " ", with: "-")) {
                    NavigationLink {
                        PlantDetailView(plantId: parent.id)
                            .environmentObject(store)
                            .environmentObject(library)
                    } label: {
                        speciesParentTile(parent: parent)
                    }
                    .buttonStyle(.plain)
                }
                if cultivars.isEmpty {
                    Text("This species has no separately listed cultivars in the catalogue. Open the species record above to view it.")
                        .font(.custom("Nunito-SemiBold", size: 12))
                        .foregroundStyle(Color.bmText2)
                } else {
                    Text("\(cultivars.count) cultivar\(cultivars.count == 1 ? "" : "s")")
                        .font(.custom("Nunito-Bold", size: 11))
                        .foregroundStyle(Color.bmText3)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)],
                              spacing: 12) {
                        ForEach(cultivars.sorted { $0.name < $1.name }) { plant in
                            NavigationLink {
                                PlantDetailView(plantId: plant.id)
                                    .environmentObject(store)
                                    .environmentObject(library)
                            } label: {
                                cultivarTile(plant: plant)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .bmFloralBackdrop()
        .bmNavTitle(speciesName, icon: "🌸")
    }

    private func speciesParentTile(parent: Plant) -> some View {
        HStack(spacing: 12) {
            BMPlantImage(plant: parent, height: 60, cornerRadius: 10)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(parent.name)
                    .font(.custom("Fredoka-SemiBold", size: 14))
                    .foregroundStyle(Color.bmText1)
                Text("Species record")
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.bmText3)
        }
        .padding(12)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.bmGreenMid, lineWidth: 1.5))
    }

    private func cultivarTile(plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BMPlantImage(plant: plant, height: 90, cornerRadius: 10)
            Text(plant.name)
                .font(.custom("Nunito-Bold", size: 12))
                .foregroundStyle(Color.bmText1)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let hex = plant.colorHex {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    if let h = plant.heightCm {
                        Text("\(h) cm")
                            .font(.custom("Nunito-Bold", size: 9))
                            .foregroundStyle(Color.bmText3)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.bmBorder, lineWidth: 1.5))
    }
}
#endif

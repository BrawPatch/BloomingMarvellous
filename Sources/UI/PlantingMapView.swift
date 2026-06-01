#if canImport(UIKit)
import SwiftUI
import UIKit
import BloomingMarvellous

// MARK: - PlantingMapView (Phase 4)
//
// Reached from the Homepage "Planting Map" tile. Shows a thumbnail card
// for every bed in the user's gardens that has at least one plant
// physically placed (bed.plantCounts non-empty). Tapping a thumbnail
// opens a fullscreen view of that bed's layout with an A4 PDF share
// button. The PDF prints cleanly as a physical planting guide.
//
// `PlantingMapView` is the new entry point; the older
// `PlantingMapPlaceholderView` alias is kept so any in-flight
// navigations still resolve while we transition callers.

public struct PlantingMapView: View {

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                introCard
                if plantedBeds.isEmpty {
                    emptyState
                } else {
                    gallery
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .bmFloralBackdrop()
        .bmNavTitle("Planting Map", icon: "🗺️")
    }

    // MARK: - Sections

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your bed layouts")
                .font(.custom("Fredoka-SemiBold", size: 16))
                .foregroundStyle(Color.bmText1)
            Text("Tap a bed to open the full layout — share it as an A4 PDF you can print and take into the garden.")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No beds have plants placed yet.")
                .font(.custom("Nunito-Bold", size: 13))
                .foregroundStyle(Color.bmText1)
            Text("Open a bed from the Beds tile, then use Plant layout to place a few species. They'll appear here as printable maps.")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var gallery: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(plantedBeds, id: \.id) { bed in
                NavigationLink {
                    BedPlantingMapDetailView(bedId: bed.id)
                        .environmentObject(store)
                        .environmentObject(library)
                } label: {
                    thumbnail(bed)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func thumbnail(_ bed: Bed) -> some View {
        let resolved = resolvedPlants(for: bed)
        let totalPlants = bed.plantCounts.values.reduce(0, +)
        return VStack(alignment: .leading, spacing: 8) {
            BedLayoutGridView(bed: bed, plants: resolved)
                .frame(height: 110)
            VStack(alignment: .leading, spacing: 2) {
                Text(bed.name)
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmText1)
                Text(gardenName(for: bed))
                    .font(.custom("Nunito-SemiBold", size: 10))
                    .foregroundStyle(Color.bmText3)
                Text("\(totalPlants) plant\(totalPlants == 1 ? "" : "s") · \(bed.plantCounts.count) species")
                    .font(.custom("Nunito-SemiBold", size: 10))
                    .foregroundStyle(Color.bmText3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.bmBorder, lineWidth: 1.5))
    }

    // MARK: - Data helpers

    private var plantedBeds: [Bed] {
        let gardenIds = Set(store.gardens.map(\.id))
        return store.beds
            .filter { gardenIds.contains($0.gardenId) && !$0.plantCounts.isEmpty }
            .sorted { $0.name < $1.name }
    }

    private func resolvedPlants(for bed: Bed) -> [String: Plant] {
        var out: [String: Plant] = [:]
        for id in bed.plantCounts.keys {
            if let p = library.plant(id: id) { out[id] = p }
        }
        return out
    }

    private func gardenName(for bed: Bed) -> String {
        store.garden(id: bed.gardenId)?.name ?? "Garden"
    }
}

// MARK: - BedPlantingMapDetailView (fullscreen + share)

struct BedPlantingMapDetailView: View {

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore
    let bedId: UUID

    @State private var sharedPayload: SharedPDF?
    @State private var pdfError: String?

    struct SharedPDF: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    var body: some View {
        Group {
            if let bed = store.bed(id: bedId),
               let garden = store.garden(id: bed.gardenId) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(bed: bed, garden: garden)
                        BedLayoutGridView(bed: bed, plants: resolved(bed: bed))
                            .frame(height: 320)
                            .padding(.horizontal, 4)
                        legend(bed: bed)
                        shareButton(bed: bed, garden: garden)
                        if let err = pdfError {
                            Text(err)
                                .font(.custom("Nunito-SemiBold", size: 12))
                                .foregroundStyle(Color.bmRed)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            } else {
                Text("Bed not found.")
                    .font(.custom("Nunito-SemiBold", size: 13))
                    .foregroundStyle(Color.bmText2)
            }
        }
        .bmFloralBackdrop()
        .bmNavTitle("Bed map", icon: "🗺️")
        .sheet(item: $sharedPayload) { payload in
            ActivityShareSheet(items: [payload.url])
        }
    }

    // MARK: Sections

    private func header(bed: Bed, garden: Garden) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bed.name)
                .font(.custom("Fredoka-SemiBold", size: 20))
                .foregroundStyle(Color.bmText1)
            Text("\(bed.widthCm) × \(bed.lengthCm) cm · in \(garden.name)")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func legend(bed: Bed) -> some View {
        let plants = resolved(bed: bed)
        let ordered = bed.plantCounts.keys.sorted {
            (plants[$0]?.heightCm ?? 0) > (plants[$1]?.heightCm ?? 0)
        }
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Legend", icon: "🌿")
            ForEach(ordered, id: \.self) { pid in
                if let plant = plants[pid] {
                    legendRow(plant: plant, count: bed.plantCounts[pid] ?? 0)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func legendRow(plant: Plant, count: Int) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(plant.colorHex.flatMap { Color(hex: $0) } ?? Color.bmGreen)
                .frame(width: 12, height: 12)
            Text("\(plant.name) ×\(count)")
                .font(.custom("Nunito-Bold", size: 12))
                .foregroundStyle(Color.bmText1)
            Spacer()
            Text(footprint(plant))
                .font(.custom("Nunito-SemiBold", size: 10))
                .foregroundStyle(Color.bmText3)
        }
    }

    private func footprint(_ plant: Plant) -> String {
        var parts: [String] = []
        if let s = plant.spreadCm { parts.append("\(s) cm spread") }
        if let h = plant.heightCm { parts.append("\(h) cm tall") }
        return parts.joined(separator: " · ")
    }

    private func shareButton(bed: Bed, garden: Garden) -> some View {
        Button(action: { exportPDF(bed: bed, garden: garden) }) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("Share as A4 PDF")
                    .font(.custom("Fredoka-SemiBold", size: 14))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.bmGreen)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func exportPDF(bed: Bed, garden: Garden) {
        pdfError = nil
        let plants = resolved(bed: bed)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlantingMap-\(safeName(bed.name)).pdf")
        do {
            try BedPlantingMapPDF.render(bed: bed,
                                         gardenName: garden.name,
                                         plants: plants,
                                         to: url)
            sharedPayload = SharedPDF(url: url)
        } catch {
            pdfError = "Couldn't build PDF: \(error.localizedDescription)"
        }
    }

    private func resolved(bed: Bed) -> [String: Plant] {
        var out: [String: Plant] = [:]
        for id in bed.plantCounts.keys {
            if let p = library.plant(id: id) { out[id] = p }
        }
        return out
    }

    private func safeName(_ s: String) -> String {
        s.replacingOccurrences(of: " ", with: "_")
         .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }
}

// MARK: - ActivityShareSheet (UIKit bridge for the system share sheet)

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

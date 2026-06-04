#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - MyBedsView
//
// Landing page reached from the Home "My Beds" tile. Lists every bed
// across the user's gardens with two side-by-side actions per row:
//
//   • Edit Bed — pushes the bed's BedDetailView (conditions, plant
//                counts, season history, etc.)
//   • Bed Map  — pushes the BedMapEditorView (drag-and-drop layout
//                editor and PDF export).
//
// Free-tier users have a single garden; Pro users get a section header
// per garden so multi-garden setups still read tidily. Bed creation
// happens in Settings → Gardens & beds, this screen stays focused on
// "I have beds, now what do I do with them?".

public struct MyBedsView: View {

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore
    @AppStorage(LengthUnit.storageKey) private var lengthUnitRaw: String = LengthUnit.metres.rawValue
    private var lengthUnit: LengthUnit { LengthUnit(rawValue: lengthUnitRaw) ?? .metres }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.gardens.isEmpty {
                    emptyState
                } else {
                    ForEach(store.gardens) { garden in
                        gardenSection(garden: garden)
                    }
                    settingsHint
                }
            }
            .padding(16)
        }
        .bmFloralBackdrop()
        .bmNavTitle("My beds", icon: "🪴")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ContextualHelpButton(topic: .beds)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func gardenSection(garden: Garden) -> some View {
        let beds = store.beds(in: garden.id)
        VStack(alignment: .leading, spacing: 10) {
            if store.gardens.count > 1 {
                HStack(spacing: 6) {
                    Text("🌷 \(garden.name)")
                        .font(.custom("Fredoka-SemiBold", size: 15))
                        .foregroundStyle(Color.bmText1)
                    Text("·")
                        .foregroundStyle(Color.bmText3)
                    Text("\(beds.count) bed\(beds.count == 1 ? "" : "s")")
                        .font(.custom("Nunito-SemiBold", size: 11))
                        .foregroundStyle(Color.bmText3)
                    Spacer()
                }
            }
            if beds.isEmpty {
                Text("No beds yet for this garden — add some in Settings → Gardens & beds.")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText3)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .bmCard()
            } else {
                ForEach(beds) { bed in
                    bedCard(bed: bed)
                }
            }
        }
    }

    private func bedCard(bed: Bed) -> some View {
        let counted = bed.plantCounts.values.reduce(0, +)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(bed.name)
                    .font(.custom("Fredoka-SemiBold", size: 16))
                    .foregroundStyle(Color.bmText1)
                Spacer()
                Text(bed.dimensionLabel(unit: lengthUnit))
                    .font(.custom("Nunito-Bold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }
            HStack(spacing: 8) {
                statusChip(bed: bed)
                if counted > 0 {
                    Text("\(counted) plant\(counted == 1 ? "" : "s")")
                        .font(.custom("Nunito-Bold", size: 10))
                        .foregroundStyle(Color.bmGreen)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.bmGreen.opacity(0.15))
                        .clipShape(Capsule())
                }
                if !bed.history.isEmpty {
                    Text("\(bed.history.count) previous season\(bed.history.count == 1 ? "" : "s")")
                        .font(.custom("Nunito-Bold", size: 10))
                        .foregroundStyle(Color.bmLilac)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.bmLilac.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
            }
            HStack(spacing: 8) {
                NavigationLink {
                    BedDetailView(bedId: bed.id)
                        .environmentObject(store)
                        .environmentObject(library)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                        Text("Edit Bed")
                            .font(.custom("Fredoka-SemiBold", size: 13))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.bmGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                NavigationLink {
                    BedMapEditorView(bedId: bed.id)
                        .environmentObject(store)
                        .environmentObject(library)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "map")
                            .font(.system(size: 12, weight: .bold))
                        Text("Bed Map")
                            .font(.custom("Fredoka-SemiBold", size: 13))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.bmLilac)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func statusChip(bed: Bed) -> some View {
        Text(bed.status.label)
            .font(.custom("Fredoka-SemiBold", size: 10))
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(statusColour(bed.status))
            .clipShape(Capsule())
    }

    private func statusColour(_ status: BedStatus) -> Color {
        switch status {
        case .planned: return .bmAmber
        case .active:  return .bmGreen
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No gardens yet.")
                .font(.custom("Fredoka-SemiBold", size: 16))
                .foregroundStyle(Color.bmText1)
            Text("Add your first garden + bed in Settings → Gardens & beds to start using this page.")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var settingsHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundStyle(Color.bmText3)
            Text("Add, rename or delete beds in Settings → Gardens & beds.")
                .font(.custom("Nunito-SemiBold", size: 11))
                .foregroundStyle(Color.bmText3)
            Spacer()
        }
        .padding(.horizontal, 12)
    }
}
#endif

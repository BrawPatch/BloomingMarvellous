#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - MyCurrentPlantsView
//
// Bottom-tab destination listing every plant the gardener is growing
// (or used to grow). Two top-level sections:
//
//   • Current — plants currently in any bed (plantCounts), flagged
//               perennials, or picks for the current / upcoming months.
//   • Past    — plants that appear in any bed's season history but are
//               no longer in the Current roster (typically annuals
//               cleared when the gardener started a new season).
//
// Each section is sub-grouped by PlantGroup (Flower / Vegetable / Herb
// / Fruit), and within each group by genus — mirroring the picker's
// gallery drill-down so the gardener has one mental model to learn.
//
// Each row exposes a notes editor sheet and a "Won't grow again" toggle.
// Flagging a plant adds its id to GardenStore.wontGrowAgainIds, which
// the picker pipeline reads and uses to exclude the plant from future
// search results until the gardener un-toggles it from here.

public struct MyCurrentPlantsView: View {

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore

    @State private var tab: Tab = .current
    @State private var editingNotesFor: String?

    public init() {}

    private enum Tab: Hashable { case current, past }

    public var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                tabBar
                    .padding(.horizontal, 16)
                content
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 14)
        }
        .bmFloralBackdrop()
        .bmNavTitle("My plants", icon: "🌱")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ContextualHelpButton(topic: .plantManagement)
            }
        }
        .sheet(item: Binding(
            get: { editingNotesFor.map { PlantIdToken(id: $0) } },
            set: { editingNotesFor = $0?.id })) { token in
            NotesEditorSheet(plantId: token.id)
                .environmentObject(store)
                .environmentObject(library)
        }
    }

    private struct PlantIdToken: Identifiable, Hashable { let id: String }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(.current, label: "Current (\(currentPlants.count))")
            tabButton(.past,    label: "Past (\(pastPlants.count))")
        }
        .padding(4)
        .background(Color.bmBgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.bmBorder, lineWidth: 1.5))
    }

    private func tabButton(_ value: Tab, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { tab = value }
        } label: {
            Text(label)
                .font(.custom("Fredoka-SemiBold", size: 13))
                .foregroundStyle(tab == value ? .white : Color.bmText2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(tab == value ? Color.bmGreen : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let plants = (tab == .current) ? currentPlants : pastPlants
        if plants.isEmpty {
            emptyState
        } else {
            let typeGroups = typeGroups(in: plants)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(typeGroups, id: \.group) { typeBucket in
                    typeSection(typeBucket: typeBucket)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tab == .current
                 ? "No plants in your beds yet."
                 : "No retired plants yet — start a new season from a bed once your annuals are spent to see them appear here.")
                .font(.custom("Nunito-SemiBold", size: 13))
                .foregroundStyle(Color.bmText2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    // MARK: - Type → Genus drill-down

    private struct TypeBucket {
        let group: PlantGroup
        let genusBuckets: [GalleryDrillDown.GenusBucket]
    }

    private func typeGroups(in plants: [Plant]) -> [TypeBucket] {
        let byGroup = Dictionary(grouping: plants) { PlantGroup.group(for: $0) }
        return PlantGroup.allCases.compactMap { g -> TypeBucket? in
            guard let bucket = byGroup[g], !bucket.isEmpty else { return nil }
            return TypeBucket(group: g,
                              genusBuckets: GalleryDrillDown.genusBuckets(plants: bucket))
        }
    }

    @ViewBuilder
    private func typeSection(typeBucket: TypeBucket) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(typeBucket.group.emoji)
                Text(typeBucket.group.label.uppercased())
                    .font(.custom("Fredoka-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText2)
                    .kerning(0.6)
                Spacer()
                let total = typeBucket.genusBuckets.reduce(0) { $0 + $1.plants.count }
                Text("\(total)")
                    .font(.custom("Nunito-Bold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }
            ForEach(typeBucket.genusBuckets, id: \.label) { genus in
                genusSubsection(genus: genus)
            }
        }
    }

    @ViewBuilder
    private func genusSubsection(genus: GalleryDrillDown.GenusBucket) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(GalleryDrillDown.pluralise(genus.label))
                .font(.custom("Fredoka-SemiBold", size: 13))
                .foregroundStyle(Color.bmText1)
            ForEach(genus.plants.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }) { plant in
                plantRow(plant: plant)
            }
        }
    }

    private func plantRow(plant: Plant) -> some View {
        let n = store.notes(for: plant.id)
        return VStack(spacing: 6) {
            NavigationLink {
                PlantDetailView(plantId: plant.id)
                    .environmentObject(store)
                    .environmentObject(library)
            } label: {
                PlantListRow(plant: plant) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.bmText3)
                }
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                Button {
                    editingNotesFor = plant.id
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: n.notes.isEmpty ? "square.and.pencil" : "note.text")
                            .font(.system(size: 11, weight: .bold))
                        Text(n.notes.isEmpty ? "Add notes" : "Edit notes")
                            .font(.custom("Fredoka-SemiBold", size: 11))
                    }
                    .foregroundStyle(Color.bmGreen)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .overlay(Capsule().stroke(Color.bmGreen, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "xmark.octagon")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(store.wontGrowAgain(plant.id) ? Color.bmRed : Color.bmText3)
                    Text("Won't grow again")
                        .font(.custom("Nunito-Bold", size: 11))
                        .foregroundStyle(Color.bmText2)
                    Toggle("", isOn: Binding(
                        get: { store.wontGrowAgain(plant.id) },
                        set: { store.setWontGrowAgain($0, for: plant.id) }))
                        .toggleStyle(.switch)
                        .tint(Color.bmRed)
                        .labelsHidden()
                }
            }
            if !n.notes.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.bmText3)
                    Text(n.notes)
                        .font(.custom("Nunito-SemiBold", size: 11))
                        .foregroundStyle(Color.bmText2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 10)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Roster computations

    private var currentPlants: [Plant] {
        store.currentPlantIds.compactMap { library.plant(id: $0) }
    }

    private var pastPlants: [Plant] {
        store.pastPlantIds.compactMap { library.plant(id: $0) }
    }
}

// MARK: - NotesEditorSheet

struct NotesEditorSheet: View {
    let plantId: String

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var wontGrow: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let plant = library.plant(id: plantId) {
                        PlantListRow(plant: plant)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.custom("Nunito-Bold", size: 13))
                            .foregroundStyle(Color.bmText1)
                        TextEditor(text: $text)
                            .font(.custom("Nunito-SemiBold", size: 13))
                            .frame(minHeight: 140)
                            .padding(8)
                            .background(Color.bmBgSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.bmBorder, lineWidth: 1))
                    }
                    Toggle(isOn: $wontGrow) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Won't grow again")
                                .font(.custom("Nunito-Bold", size: 13))
                                .foregroundStyle(Color.bmText1)
                            Text("Excludes this plant from future picker results until you untick it here.")
                                .font(.custom("Nunito-SemiBold", size: 11))
                                .foregroundStyle(Color.bmText3)
                        }
                    }
                    .tint(Color.bmRed)
                    Button {
                        save()
                    } label: {
                        Text("Save")
                            .font(.custom("Fredoka-SemiBold", size: 14))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.bmGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .bmSheetBackdrop()
            .bmNavTitle("Plant notes", icon: "📝")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.bmText2)
                }
            }
            .onAppear {
                let n = store.notes(for: plantId)
                text = n.notes
                wontGrow = n.wontGrowAgain
            }
        }
    }

    private func save() {
        store.setNotes(text, for: plantId)
        store.setWontGrowAgain(wontGrow, for: plantId)
        dismiss()
    }
}
#endif

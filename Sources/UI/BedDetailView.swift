#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - BedDetailView

public struct BedDetailView: View {

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore
    @AppStorage(LengthUnit.storageKey) private var lengthUnitRaw: String = LengthUnit.metres.rawValue
    private var lengthUnit: LengthUnit { LengthUnit(rawValue: lengthUnitRaw) ?? .metres }
    @State private var showingSoilOverride = false
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var showingNewSeasonConfirm = false
    @SwiftUI.Environment(\.dismiss) private var dismiss

    let bedId: UUID

    public init(bedId: UUID) { self.bedId = bedId }

    public var body: some View {
        Group {
            if let bed = store.bed(id: bedId),
               let garden = store.garden(id: bed.gardenId) {
                ScrollView {
                    VStack(spacing: 16) {
                        summaryCard(bed, garden)
                        conditionsCard(bed, garden)
                        timelineCard(bed)
                        cropsCard(bed)
                        if store.user.tier == .pro {
                            plantLayoutCard(bed)
                        }
                        deleteButton
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
        .bmNavTitle("Bed detail", icon: "🪴")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundStyle(Color.bmGreen)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ContextualHelpButton(topic: .bedDetail)
            }
        }
        .sheet(isPresented: $showingSoilOverride) {
            NavigationStack {
                SoilView(scope: .bed(bedId))
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let bed = store.bed(id: bedId) {
                EditBedView(bed: bed)
                    .environmentObject(store)
            }
        }
        .confirmationDialog("Delete bed?",
                            isPresented: $showingDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.deleteBed(id: bedId)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This bed and its crops will be removed. This can't be undone.")
        }
        .confirmationDialog("Start a new planting season?",
                            isPresented: $showingNewSeasonConfirm,
                            titleVisibility: .visible) {
            Button("Start new season", role: .destructive) {
                store.startNewSeason(bedId: bedId)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Annuals will be cleared so this bed is ready for new planting. Perennials stay in place and will be marked \"Carried over from last year\".")
        }
    }

    // MARK: - Cards

    private func summaryCard(_ bed: Bed, _ garden: Garden) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(bed.name)
                    .font(.custom("Fredoka-SemiBold", size: 20))
                    .foregroundStyle(Color.bmText1)
                Spacer()
                Text(bed.status.label.uppercased())
                    .font(.custom("Fredoka-SemiBold", size: 9))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(bed.status == .active ? Color.bmGreen : Color.bmAmber)
                    .clipShape(Capsule())
            }
            Text("\(bed.dimensionLabel(unit: lengthUnit)) · in \(garden.name)")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func conditionsCard(_ bed: Bed, _ garden: Garden) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Conditions", icon: "🌍")
                Spacer()
                if bed.overridesGarden {
                    Text("Overridden")
                        .font(.custom("Fredoka-SemiBold", size: 9))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.bmLilac)
                        .clipShape(Capsule())
                }
            }
            row("Soil",     bed.effectiveSoil(garden: garden).label,
                overridden: bed.soilTypeOverride != nil)
            row("Wetness",  bed.effectiveWetness(garden: garden).label,
                overridden: bed.wetnessOverride != nil)
            row("Exposure", bed.effectiveExposure(garden: garden).label,
                overridden: bed.exposureOverride != nil)
            row("Sunlight", bed.effectiveSunlight(garden: garden).label,
                overridden: bed.sunlightOverride != nil)
            Button {
                showingSoilOverride = true
            } label: {
                Text(bed.overridesGarden ? "Edit override" : "Override garden defaults")
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundStyle(Color.bmGreen)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private func timelineCard(_ bed: Bed) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Planting timeline", icon: "📅")
            // Simple 12-month track placeholder — gets populated once the
            // user adds crops to the bed.
            HStack(spacing: 2) {
                ForEach(1...12, id: \.self) { m in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.bmBgMint)
                            .frame(height: 18)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Text(monthAbbr(m))
                            .font(.custom("Nunito-Bold", size: 8))
                            .foregroundStyle(Color.bmText3)
                    }
                }
            }
            Text("Add crops to see sow / transplant / harvest events.")
                .font(.custom("Nunito-SemiBold", size: 11))
                .foregroundStyle(Color.bmText3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    @ViewBuilder
    private func cropsCard(_ bed: Bed) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Crops in bed", icon: "🌱")
                Spacer()
                if store.user.tier == .pro {
                    let total = picksByMonth(forBed: bed.id).reduce(0) { $0 + $1.plants.count }
                    if total > 0 {
                        Text("\(total) pick\(total == 1 ? "" : "s")")
                            .font(.custom("Nunito-Bold", size: 11))
                            .foregroundStyle(Color.bmText3)
                    }
                }
            }

            if store.user.tier == .free {
                Text("Free tier — crops are planned at the garden level. Upgrade to Pro to plan per bed.")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText2)
            } else {
                let groups = picksByMonth(forBed: bed.id)
                if groups.isEmpty {
                    Text("No crops yet. Open the Plant Picker, choose a plant, and tap the months you want it to bloom in this bed.")
                        .font(.custom("Nunito-SemiBold", size: 12))
                        .foregroundStyle(Color.bmText2)
                    NavigationLink {
                        PlantPickerMonthView()
                            .onAppear { store.selectedBedId = bed.id }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Pick plants for this bed")
                                .font(.custom("Fredoka-SemiBold", size: 13))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.bmGreen)
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                } else {
                    ForEach(groups, id: \.month) { group in
                        cropRow(bed: bed, month: group.month, plants: group.plants)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    /// Resolves picks per month for `bedId` against the LibraryStore (so
    /// plants from the server library are surfaced, not just the bundled
    /// fallback).
    private func picksByMonth(forBed bedId: UUID) -> [(month: Int, plants: [Plant])] {
        (1...12).compactMap { m in
            let plants = store.picks(month: m, bedId: bedId).compactMap(library.plant(id:))
            return plants.isEmpty ? nil : (m, plants)
        }
    }

    private func cropRow(bed: Bed, month: Int, plants: [Plant]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(monthAbbr(month))
                .font(.custom("Fredoka-SemiBold", size: 11))
                .foregroundStyle(Color.bmGreen)
                .kerning(0.5)
            ForEach(plants) { p in
                HStack {
                    Text(p.name)
                        .font(.custom("Nunito-Bold", size: 13))
                        .foregroundStyle(Color.bmText1)
                    Text(p.latin)
                        .font(.custom("Nunito-SemiBold", size: 11))
                        .foregroundStyle(Color.bmText3)
                        .italic()
                    Spacer()
                    Button {
                        store.togglePick(plantId: p.id, month: month, bedId: bed.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Color.bmRed.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.bmBgSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Plant layout (Phase 3)

    /// Resolves Plant records for every species relevant to this bed —
    /// already-placed (plantCounts) plus every plant the user has picked
    /// for any bloom month in this bed (candidates the Add sheet can show).
    private func resolvedPlantsForLayout(bed: Bed) -> [String: Plant] {
        var ids = Set(bed.plantCounts.keys)
        for (_, list) in (1...12).map({ ($0, store.picks(month: $0, bedId: bed.id)) }) {
            ids.formUnion(list)
        }
        var resolved: [String: Plant] = [:]
        for id in ids {
            if let p = library.plant(id: id) { resolved[id] = p }
        }
        return resolved
    }

    @ViewBuilder
    private func plantLayoutCard(_ bed: Bed) -> some View {
        let resolved = resolvedPlantsForLayout(bed: bed)
        let capacity = BedCapacityModel(bed: bed, plants: resolved)
        let layoutIds = layoutSpeciesIds(bed: bed, resolved: resolved)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Plant layout", icon: "🗺️")
                Spacer()
                Text(fillLabel(capacity))
                    .font(.custom("Nunito-Bold", size: 11))
                    .foregroundStyle(Color.bmText3)
            }

            fillBar(fraction: capacity.fillFraction)

            if layoutIds.isEmpty {
                Text("No bloom picks for this bed yet. Pick a plant in the Plant Picker — it'll appear here with a stepper so you can set how many you'd like.")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundStyle(Color.bmText2)
            } else {
                if !bed.plantCounts.isEmpty {
                    BedLayoutGridView(bed: bed, plants: resolved)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }

                ForEach(layoutIds, id: \.self) { pid in
                    if let plant = resolved[pid] {
                        plantCountRow(bed: bed, plant: plant, capacity: capacity)
                    }
                }
            }

            HStack(spacing: 10) {
                // Hand off straight to the Plant Picker scoped to this
                // bed — picks land in bedPicks for `bed.id` and the
                // layout card auto-surfaces them with a stepper on the
                // gardener's return. Bypasses the old narrow sheet.
                NavigationLink {
                    PlantPickerMonthView()
                        .environmentObject(store)
                        .environmentObject(library)
                        .onAppear {
                            store.selectedGardenId = bed.gardenId
                            store.selectedBedId = bed.id
                        }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add a plant")
                            .font(.custom("Fredoka-SemiBold", size: 13))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.bmGreen)
                    .clipShape(Capsule())
                }

                if !bed.plantCounts.isEmpty {
                    Button {
                        showingNewSeasonConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .bold))
                            Text("Start new season")
                                .font(.custom("Fredoka-SemiBold", size: 12))
                        }
                        .foregroundStyle(Color.bmGreen)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .overlay(Capsule().stroke(Color.bmGreen, lineWidth: 1.5))
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    /// All species the Plant layout card should render a stepper for —
    /// the union of plants the user has physically placed (`plantCounts`)
    /// and plants they've bloom-picked anywhere in this bed (`bedPicks`).
    /// Surfacing planned-but-not-placed species means the gardener can
    /// set counts inline rather than round-tripping through "Add a plant".
    private func layoutSpeciesIds(bed: Bed, resolved: [String: Plant]) -> [String] {
        var ids = Set(bed.plantCounts.keys)
        for m in 1...12 {
            ids.formUnion(store.picks(month: m, bedId: bed.id))
        }
        return ids.sorted { lhs, rhs in
            let l = resolved[lhs]?.heightCm ?? 0
            let r = resolved[rhs]?.heightCm ?? 0
            if l != r { return l > r } // tallest first
            return (resolved[lhs]?.name ?? lhs) < (resolved[rhs]?.name ?? rhs)
        }
    }

    private func plantCountRow(bed: Bed,
                               plant: Plant,
                               capacity: BedCapacityModel) -> some View {
        let count = bed.plantCounts[plant.id] ?? 0
        let atCap = capacity.atCapacity(plantId: plant.id)
        let isPerennial = bed.perennials.contains(plant.id)
        let isCarriedOver = bed.carriedOver.contains(plant.id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(plant.colorHex.flatMap { Color(hex: $0) } ?? Color.bmGreen)
                    .frame(width: 14, height: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text(plant.name)
                        .font(.custom("Nunito-Bold", size: 13))
                        .foregroundStyle(Color.bmText1)
                    Text(plantFootprintLabel(plant))
                        .font(.custom("Nunito-SemiBold", size: 11))
                        .foregroundStyle(Color.bmText3)
                }
                Spacer()
                stepperCluster(plant: plant, bed: bed, count: count, atCap: atCap)
            }

            HStack(spacing: 6) {
                Button {
                    store.togglePerennial(plantId: plant.id, in: bed.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isPerennial ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 11, weight: .bold))
                        Text("Perennial")
                            .font(.custom("Nunito-Bold", size: 11))
                    }
                    .foregroundStyle(isPerennial ? Color.bmGreen : Color.bmText3)
                }
                .buttonStyle(.plain)

                if isCarriedOver {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("Carried over from last year")
                            .font(.custom("Fredoka-SemiBold", size: 9))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.bmLeafSage)
                    .clipShape(Capsule())

                    Button {
                        store.setPlantCount(plantId: plant.id, in: bed.id, to: 0)
                    } label: {
                        Text("Remove last season's")
                            .font(.custom("Nunito-Bold", size: 11))
                            .foregroundStyle(Color.bmRed)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            if atCap {
                Text("Free up space to add more plants.")
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmAmber)
            }
        }
        .padding(10)
        .background(Color.bmBgSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func stepperCluster(plant: Plant,
                                bed: Bed,
                                count: Int,
                                atCap: Bool) -> some View {
        // Decrement icon shifts between three states:
        //   • count == 0 → minus disabled (nothing to remove)
        //   • count == 1 → trash (next tap removes the species)
        //   • count > 1  → minus (next tap drops by one)
        let canDecrement = count > 0
        return HStack(spacing: 8) {
            Button {
                if count <= 1 {
                    store.setPlantCount(plantId: plant.id, in: bed.id, to: 0)
                } else {
                    store.adjustPlantCount(plantId: plant.id, in: bed.id, by: -1)
                }
            } label: {
                Image(systemName: count == 1 ? "trash.fill" : "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(decrementColor(count: count)))
            }
            .buttonStyle(.plain)
            .disabled(!canDecrement)

            Text("\(count)")
                .font(.custom("Fredoka-SemiBold", size: 14))
                .foregroundStyle(count == 0 ? Color.bmText3 : Color.bmText1)
                .frame(minWidth: 20)

            Button {
                store.adjustPlantCount(plantId: plant.id, in: bed.id, by: 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(atCap ? Color.bmText3 : Color.bmGreen))
            }
            .buttonStyle(.plain)
            .disabled(atCap)
        }
    }

    private func decrementColor(count: Int) -> Color {
        if count == 0 { return Color.bmText3 }
        if count == 1 { return Color.bmRed }
        return Color.bmText2
    }

    private func plantFootprintLabel(_ plant: Plant) -> String {
        var parts: [String] = []
        if let h = plant.heightCm { parts.append("\(h) cm tall") }
        if let s = plant.spreadCm { parts.append("\(s) cm spread") }
        return parts.joined(separator: " · ")
    }

    private func fillLabel(_ capacity: BedCapacityModel) -> String {
        let pct = Int((capacity.fillFraction * 100).rounded())
        return "\(pct)% full"
    }

    private func fillBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.bmBgSoft)
                RoundedRectangle(cornerRadius: 4)
                    .fill(fraction >= 1.0 ? Color.bmAmber : Color.bmGreen)
                    .frame(width: geo.size.width * CGFloat(min(1.0, fraction)))
            }
        }
        .frame(height: 6)
    }

    private var deleteButton: some View {
        Button {
            showingDeleteConfirm = true
        } label: {
            Text("Delete bed")
                .font(.custom("Nunito-Bold", size: 13))
                .foregroundStyle(Color.bmRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.bmRed.opacity(0.4), lineWidth: 1.5))
        }
    }

    private func row(_ label: String, _ value: String, overridden: Bool) -> some View {
        HStack {
            Text(label)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
            Spacer()
            Text(value)
                .font(.custom("Nunito-Bold", size: 13))
                .foregroundStyle(overridden ? Color.bmLilac : Color.bmText1)
        }
    }

    private func monthAbbr(_ m: Int) -> String {
        ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][m - 1]
    }
}

// MARK: - EditBedView (rename / resize / change status)

struct EditBedView: View {
    @EnvironmentObject private var store: GardenStore
    @AppStorage(LengthUnit.storageKey) private var lengthUnitRaw: String = LengthUnit.metres.rawValue
    private var lengthUnit: LengthUnit { LengthUnit(rawValue: lengthUnitRaw) ?? .metres }
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State var bed: Bed

    var body: some View {
        NavigationStack {
            Form {
                Section("Bed") {
                    TextField("Name", text: $bed.name)
                    Stepper("Width: \(LengthFormat.display(cm: bed.widthCm, unit: lengthUnit))",
                            value: $bed.widthCm, in: 30...500, step: 10)
                    Stepper("Length: \(LengthFormat.display(cm: bed.lengthCm, unit: lengthUnit))",
                            value: $bed.lengthCm, in: 30...1000, step: 10)
                    Picker("Status", selection: $bed.status) {
                        ForEach(BedStatus.allCases) { Text($0.label).tag($0) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .bmSheetBackdrop()
            .bmNavTitle("Edit bed", icon: "🪴")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateBed(bed)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
#endif

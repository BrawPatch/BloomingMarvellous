#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - BedDetailView

public struct BedDetailView: View {

    @EnvironmentObject private var store: GardenStore
    @State private var showingSoilOverride = false
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
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
            Text("\(bed.dimensionLabel) · in \(garden.name)")
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
                    let total = store.picksByMonth(bedId: bed.id).reduce(0) { $0 + $1.plants.count }
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
                let groups = store.picksByMonth(bedId: bed.id)
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
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State var bed: Bed

    var body: some View {
        NavigationStack {
            Form {
                Section("Bed") {
                    TextField("Name", text: $bed.name)
                    Stepper("Width: \(bed.widthCm) cm", value: $bed.widthCm, in: 30...500, step: 10)
                    Stepper("Length: \(bed.lengthCm) cm", value: $bed.lengthCm, in: 30...1000, step: 10)
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

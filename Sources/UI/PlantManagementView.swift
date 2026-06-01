#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - PlantManagementView (Pro)
//
// Phase 6 surface for the Phase 7 plant-management workflow. Lists every
// (plant, bed) placement across the user's gardens so the gardener can
// scan their entire collection in one place. Filters from the shared
// ScheduleFilterBar narrow by garden and bed (the task-kind row is
// hidden — Plant Management is plant-centric, not task-centric).
//
// Phase 7 will add push notification opt-ins and per-plant scheduling
// directly off these rows; for now the view is read-only.

public struct PlantManagementView: View {

    @EnvironmentObject private var store: GardenStore
    @EnvironmentObject private var library: LibraryStore
    @State private var filters = ScheduleFilters()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ScheduleFilterBar(filters: $filters,
                                  gardens: store.gardens,
                                  beds: store.beds,
                                  showKinds: false)
                    .padding(.horizontal, 4)

                if store.user.tier == .free {
                    freeState
                } else if filteredPlacements.isEmpty {
                    emptyState
                } else {
                    placementsCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .bmFloralBackdrop()
        .bmNavTitle("Plant management", icon: "🌿")
    }

    // MARK: - Sections

    private var freeState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Available on Pro")
                .font(.custom("Fredoka-SemiBold", size: 14))
                .foregroundStyle(Color.bmText1)
            Text("Plant management aggregates every plant across all of your gardens and beds. Upgrade to Pro to see your entire collection in one filterable list.")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No plants placed yet")
                .font(.custom("Fredoka-SemiBold", size: 14))
                .foregroundStyle(Color.bmText1)
            Text("Open a bed from the Beds tile and use Plant layout to place a few species. They'll appear here grouped by species.")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    private var placementsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Your plants (\(filteredPlacements.count))", icon: "🌿")
            ForEach(groupedBySpecies, id: \.plantId) { group in
                speciesGroup(group)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard()
    }

    @ViewBuilder
    private func speciesGroup(_ group: SpeciesGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(group.plant.colorHex.flatMap { Color(hex: $0) } ?? Color.bmGreen)
                    .frame(width: 14, height: 14)
                Text(group.plant.name)
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundStyle(Color.bmText1)
                Text(group.plant.latin)
                    .font(.custom("Nunito-SemiBold", size: 11))
                    .foregroundStyle(Color.bmText3)
                    .italic()
                Spacer()
                Text("×\(group.totalCount)")
                    .font(.custom("Fredoka-SemiBold", size: 13))
                    .foregroundStyle(Color.bmGreen)
            }
            ForEach(group.placements, id: \.bedId) { placement in
                placementRow(placement)
            }
        }
        .padding(.vertical, 4)
    }

    private func placementRow(_ placement: Placement) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.bmText3)
            Text("\(placement.gardenName) · \(placement.bedName)")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundStyle(Color.bmText2)
            Spacer()
            if placement.carriedOver {
                Text("Carried over")
                    .font(.custom("Fredoka-SemiBold", size: 9))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.bmLeafSage)
                    .clipShape(Capsule())
            } else if placement.perennial {
                Text("Perennial")
                    .font(.custom("Fredoka-SemiBold", size: 9))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.bmGreen)
                    .clipShape(Capsule())
            }
            Text("×\(placement.count)")
                .font(.custom("Nunito-Bold", size: 12))
                .foregroundStyle(Color.bmText1)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.bmBgSoft)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Data

    fileprivate struct Placement {
        let plantId: String
        let count: Int
        let gardenId: UUID
        let gardenName: String
        let bedId: UUID
        let bedName: String
        let perennial: Bool
        let carriedOver: Bool
    }

    fileprivate struct SpeciesGroup {
        let plantId: String
        let plant: Plant
        let placements: [Placement]
        var totalCount: Int { placements.reduce(0) { $0 + $1.count } }
    }

    private var filteredPlacements: [Placement] {
        var out: [Placement] = []
        for bed in store.beds {
            guard filters.includes(bedId: bed.id) else { continue }
            guard let garden = store.garden(id: bed.gardenId) else { continue }
            guard filters.includes(gardenId: garden.id) else { continue }
            for (pid, count) in bed.plantCounts where count > 0 {
                out.append(Placement(
                    plantId: pid,
                    count: count,
                    gardenId: garden.id,
                    gardenName: garden.name,
                    bedId: bed.id,
                    bedName: bed.name,
                    perennial: bed.perennials.contains(pid),
                    carriedOver: bed.carriedOver.contains(pid)))
            }
        }
        return out
    }

    private var groupedBySpecies: [SpeciesGroup] {
        let byId = Dictionary(grouping: filteredPlacements, by: \.plantId)
        return byId.compactMap { (pid, placements) -> SpeciesGroup? in
            guard let plant = library.plant(id: pid) else { return nil }
            return SpeciesGroup(plantId: pid,
                                plant: plant,
                                placements: placements.sorted { $0.bedName < $1.bedName })
        }
        .sorted { $0.plant.name < $1.plant.name }
    }
}
#endif

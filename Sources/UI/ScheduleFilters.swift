#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - ScheduleTaskKind
//
// Task kinds the Phase 6 filter row knows how to filter on. Mirrors the
// `EventKind` already used by PlantingScheduleView but lives in its own
// public type so PlantManagementView (Phase 7 surface) can share it.

public enum ScheduleTaskKind: String, CaseIterable, Hashable, Identifiable {
    case sow, transplant, harvest, reminder
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .sow:        return "Sow"
        case .transplant: return "Transplant"
        case .harvest:    return "Harvest"
        case .reminder:   return "Reminder"
        }
    }
    public var emoji: String {
        switch self {
        case .sow:        return "🌱"
        case .transplant: return "🪴"
        case .harvest:    return "🧺"
        case .reminder:   return "🔔"
        }
    }
    public var color: Color {
        switch self {
        case .sow:        return .bmGreen
        case .transplant: return .bmLilac
        case .harvest:    return .bmPeach
        case .reminder:   return .bmAmber
        }
    }
}

// MARK: - ScheduleFilters
//
// Multi-select filter state shared by PlantingScheduleView and the
// upcoming PlantManagementView. Empty `selected*Ids` sets mean
// "everything passes" — the default, since Phase 6 defaults the schedule
// to span all gardens and beds.

public struct ScheduleFilters: Equatable {
    public var selectedKinds: Set<ScheduleTaskKind>
    public var selectedGardenIds: Set<UUID>
    public var selectedBedIds: Set<UUID>

    public init(selectedKinds: Set<ScheduleTaskKind> = Set(ScheduleTaskKind.allCases),
                selectedGardenIds: Set<UUID> = [],
                selectedBedIds: Set<UUID> = []) {
        self.selectedKinds = selectedKinds
        self.selectedGardenIds = selectedGardenIds
        self.selectedBedIds = selectedBedIds
    }

    public func includes(kind: ScheduleTaskKind) -> Bool {
        selectedKinds.contains(kind)
    }
    public func includes(gardenId: UUID) -> Bool {
        selectedGardenIds.isEmpty || selectedGardenIds.contains(gardenId)
    }
    public func includes(bedId: UUID?) -> Bool {
        guard let id = bedId else { return selectedBedIds.isEmpty }
        return selectedBedIds.isEmpty || selectedBedIds.contains(id)
    }
}

// MARK: - ScheduleFilterBar
//
// Visual filter row used by both the Planting Schedule and Plant
// Management screens. Each row of chips toggles a single dimension —
// task kind, garden, bed — and the caller chooses which dimensions are
// relevant (Plant Management hides the task chips since plants don't
// have task kinds per se).

struct ScheduleFilterBar: View {

    @Binding var filters: ScheduleFilters
    let gardens: [Garden]
    let beds: [Bed]
    let showKinds: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showKinds {
                chipRow(title: "Tasks") {
                    ForEach(ScheduleTaskKind.allCases) { kind in
                        PillButton(
                            "\(kind.emoji) \(kind.label)",
                            isActive: filters.selectedKinds.contains(kind),
                            color: kind.color
                        ) {
                            if filters.selectedKinds.contains(kind) {
                                filters.selectedKinds.remove(kind)
                            } else {
                                filters.selectedKinds.insert(kind)
                            }
                        }
                    }
                }
            }

            if gardens.count > 1 {
                chipRow(title: "Gardens") {
                    PillButton("All",
                               isActive: filters.selectedGardenIds.isEmpty,
                               color: .bmText2) {
                        filters.selectedGardenIds.removeAll()
                        filters.selectedBedIds.removeAll()
                    }
                    ForEach(gardens) { g in
                        PillButton(g.name,
                                   isActive: filters.selectedGardenIds.contains(g.id),
                                   color: .bmGreen) {
                            toggleGarden(g.id)
                        }
                    }
                }
            }

            let visibleBeds = filteredBeds()
            if visibleBeds.count > 1 {
                chipRow(title: "Beds") {
                    PillButton("All",
                               isActive: filters.selectedBedIds.isEmpty,
                               color: .bmText2) {
                        filters.selectedBedIds.removeAll()
                    }
                    ForEach(visibleBeds) { b in
                        PillButton(b.name,
                                   isActive: filters.selectedBedIds.contains(b.id),
                                   color: .bmLeafSage) {
                            toggleBed(b.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chipRow<Content: View>(title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.custom("Fredoka-SemiBold", size: 9))
                .foregroundStyle(Color.bmText3)
                .kerning(0.5)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { content() }
                    .padding(.horizontal, 2)
            }
        }
    }

    private func toggleGarden(_ id: UUID) {
        if filters.selectedGardenIds.contains(id) {
            filters.selectedGardenIds.remove(id)
        } else {
            filters.selectedGardenIds.insert(id)
        }
        // Drop bed selections that no longer live in the active garden set.
        let activeBedIds = Set(filteredBeds().map(\.id))
        filters.selectedBedIds.formIntersection(activeBedIds)
    }

    private func toggleBed(_ id: UUID) {
        if filters.selectedBedIds.contains(id) {
            filters.selectedBedIds.remove(id)
        } else {
            filters.selectedBedIds.insert(id)
        }
    }

    private func filteredBeds() -> [Bed] {
        if filters.selectedGardenIds.isEmpty { return beds }
        return beds.filter { filters.selectedGardenIds.contains($0.gardenId) }
    }
}
#endif

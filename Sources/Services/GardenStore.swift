import Foundation
import Combine

// MARK: - GardenStore
//
// In-memory source of truth for the user's gardens, beds, and bloom-month
// plant picks. Honours the tier rules:
//
//   Free: exactly one garden; soil/wetness/exposure/sunlight are stored
//         at the garden level; beds inherit unless overridden.
//   Pro:  one or more gardens, each with one or more beds. Deleting a
//         garden cascade-deletes its beds. Beds belong to exactly one
//         garden (gardenId is non-optional).
//
// Persistence is local-only for now. A future backend turn will replace
// the in-memory arrays with a sync layer against the API. See
// `pendingBackendEndpoints` at the bottom of the file for the contract.

@MainActor
public final class GardenStore: ObservableObject {

    // MARK: - State
    @Published public private(set) var gardens: [Garden] = []
    @Published public private(set) var beds: [Bed] = []
    @Published public var selectedGardenId: UUID?

    /// `bloomPicks[gardenId][month] -> [plantId]`. Indexed by month so the
    /// Bloom Schedule can list per-month picks without rescanning.
    @Published public private(set) var bloomPicks: [UUID: [Int: [String]]] = [:]

    public let user: UserModel

    // MARK: - Init

    public init(user: UserModel,
                seedFirstGarden: Bool = true) {
        self.user = user
        if seedFirstGarden {
            let first = Garden(name: user.tier == .pro ? "My First Garden" : "My Garden")
            self.gardens = [first]
            self.selectedGardenId = first.id
        }
    }

    // MARK: - Tier rules

    /// Whether the user is allowed to add another garden.
    /// Free is capped at one; Pro is unlimited.
    public var canAddGarden: Bool {
        switch user.tier {
        case .free: return gardens.isEmpty
        case .pro:  return true
        }
    }

    /// Whether the Garden selector / manage-gardens UI should be exposed.
    /// Free shows the single garden as a static label.
    public var canManageGardens: Bool { user.tier == .pro }

    // MARK: - Garden CRUD

    public func addGarden(_ garden: Garden) {
        guard canAddGarden else { return }
        gardens.append(garden)
        if selectedGardenId == nil { selectedGardenId = garden.id }
    }

    public func updateGarden(_ garden: Garden) {
        guard let idx = gardens.firstIndex(where: { $0.id == garden.id }) else { return }
        gardens[idx] = garden
    }

    /// Deletes a garden and **cascades** to remove its beds + bloom picks.
    /// Refuses to delete the last remaining garden on Free tier (would
    /// leave the user without the required single-garden state).
    public func deleteGarden(id: UUID) {
        if user.tier == .free, gardens.count <= 1 { return }
        gardens.removeAll { $0.id == id }
        beds.removeAll { $0.gardenId == id }
        bloomPicks.removeValue(forKey: id)
        if selectedGardenId == id { selectedGardenId = gardens.first?.id }
    }

    public var selectedGarden: Garden? {
        gardens.first(where: { $0.id == selectedGardenId })
    }

    public func garden(id: UUID) -> Garden? {
        gardens.first(where: { $0.id == id })
    }

    // MARK: - Bed CRUD

    public func beds(in gardenId: UUID) -> [Bed] {
        beds.filter { $0.gardenId == gardenId }
    }

    public var bedsInSelectedGarden: [Bed] {
        guard let gid = selectedGardenId else { return [] }
        return beds(in: gid)
    }

    public func addBed(_ bed: Bed) {
        // Enforce bed-belongs-to-one-garden by trusting the constructor's
        // gardenId — we never silently re-parent.
        beds.append(bed)
    }

    public func updateBed(_ bed: Bed) {
        guard let idx = beds.firstIndex(where: { $0.id == bed.id }) else { return }
        beds[idx] = bed
    }

    public func deleteBed(id: UUID) {
        beds.removeAll { $0.id == id }
    }

    public func bed(id: UUID) -> Bed? {
        beds.first(where: { $0.id == id })
    }

    // MARK: - Bloom picks

    /// Plant IDs the user picked for `month` in the currently selected
    /// garden. Months are 1-indexed.
    public func picks(month: Int) -> [String] {
        guard let gid = selectedGardenId else { return [] }
        return bloomPicks[gid]?[month] ?? []
    }

    public func togglePick(plantId: String, month: Int) {
        guard let gid = selectedGardenId else { return }
        var byMonth = bloomPicks[gid] ?? [:]
        var list = byMonth[month] ?? []
        if let i = list.firstIndex(of: plantId) {
            list.remove(at: i)
        } else {
            list.append(plantId)
        }
        byMonth[month] = list.isEmpty ? nil : list
        bloomPicks[gid] = byMonth.isEmpty ? nil : byMonth
    }

    public func removePick(plantId: String, month: Int) {
        guard let gid = selectedGardenId else { return }
        bloomPicks[gid]?[month]?.removeAll { $0 == plantId }
        if bloomPicks[gid]?[month]?.isEmpty == true { bloomPicks[gid]?[month] = nil }
    }

    /// Convenience: month -> [Plant] resolved against the bundled library.
    public func picksByMonth() -> [(month: Int, plants: [Plant])] {
        guard let gid = selectedGardenId, let byMonth = bloomPicks[gid] else { return [] }
        return (1...12).compactMap { m in
            let plants = (byMonth[m] ?? []).compactMap { PlantLibrary.plant(id: $0) }
            return plants.isEmpty ? nil : (m, plants)
        }
    }

    // MARK: - Effective conditions
    //
    // Convenience accessors used by the Bed Detail, Soil tab badges, and
    // the scheduling views. They resolve a bed's overrides against its
    // garden defaults in a single call.

    public func effectiveConditions(forBed bed: Bed) -> (SoilType, Wetness, WeatherExposure, Sunlight)? {
        guard let g = garden(id: bed.gardenId) else { return nil }
        return (bed.effectiveSoil(garden: g),
                bed.effectiveWetness(garden: g),
                bed.effectiveExposure(garden: g),
                bed.effectiveSunlight(garden: g))
    }
}

// MARK: - Backend follow-up
//
// Endpoints to add when persistence is wired:
//
//   GET   /v1/gardens                   → [Garden]
//   POST  /v1/gardens                   body Garden, returns Garden
//   PUT   /v1/gardens/{id}              body Garden
//   DELETE /v1/gardens/{id}             cascades beds + picks server-side
//
//   GET   /v1/gardens/{id}/beds         → [Bed]
//   POST  /v1/gardens/{id}/beds         body Bed (server enforces gardenId)
//   PUT   /v1/beds/{id}                 body Bed
//   DELETE /v1/beds/{id}
//
//   GET   /v1/gardens/{id}/picks        → { "1": ["lavender","cosmos"], ... }
//   PUT   /v1/gardens/{id}/picks/{m}    body { plantIds: [...] }
//
// Tier enforcement (Free = single garden, Pro = multi) is duplicated
// server-side via the user's `tier` lookup on the sessions table.

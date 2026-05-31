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
    @Published public private(set) var gardens: [Garden] = [] { didSet { persist() } }
    @Published public private(set) var beds: [Bed]      = [] { didSet { persist() } }
    @Published public var selectedGardenId: UUID? {
        didSet {
            // Keep the bed selection inside the new garden.
            if let bid = selectedBedId, bed(id: bid)?.gardenId != selectedGardenId {
                selectedBedId = bedsInSelectedGarden.first?.id
            }
            persist()
        }
    }
    @Published public var selectedBedId: UUID? { didSet { persist() } }

    /// `bloomPicks[gardenId][month] -> [plantId]` — used on Free tier where
    /// plants are allocated at the garden level.
    @Published public private(set) var bloomPicks: [UUID: [Int: [String]]] = [:] { didSet { persist() } }

    /// `bedPicks[bedId][month] -> [plantId]` — used on Pro tier where
    /// plants are allocated per bed. Conditions still cascade Garden → Bed
    /// (with optional override), but plant suggestions are per bed.
    @Published public private(set) var bedPicks: [UUID: [Int: [String]]] = [:] { didSet { persist() } }

    /// User-entered location. Stored locally only.
    @Published public var postcode: String = "" { didSet { persist() } }
    @Published public var country:  String = "GB" { didSet { persist() } }

    public let user: UserModel

    /// Reflects the postcode in a coarse climate bucket. Recomputed when
    /// `postcode` changes.
    public var climate: ClimateProfile { ClimateProfile.lookup(postcode: postcode) }

    /// True when the user has completed the first-run Setup wizard at least
    /// once. Until then `BloomingMarvellousiOSApp` presents the wizard
    /// instead of MainTabView.
    public var hasCompletedSetup: Bool { !gardens.isEmpty && !beds.isEmpty }

    // MARK: - Init

    public init(user: UserModel,
                seedFirstGarden: Bool = true,
                defaults: UserDefaults = .standard) {
        self.user = user
        self.defaults = defaults
        self.storageKey = Self.storageKey(for: user)
        // All stored properties initialized — safe to invoke methods that
        // touch self below.
        self.restoreOrSeed(seedFirstGarden: seedFirstGarden)
    }

    private func restoreOrSeed(seedFirstGarden: Bool) {
        isPersisting = true
        defer { isPersisting = false }

        if let blob = defaults.data(forKey: storageKey),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: blob) {
            gardens          = snap.gardens
            beds             = snap.beds
            selectedGardenId = snap.selectedGardenId ?? snap.gardens.first?.id
            // Restore bed selection if it still resolves to a bed in the current garden;
            // otherwise pick the first bed of the selected garden.
            if let bid = snap.selectedBedId, snap.beds.contains(where: { $0.id == bid }) {
                selectedBedId = bid
            } else {
                selectedBedId = snap.beds.first(where: { $0.gardenId == selectedGardenId })?.id
            }
            bloomPicks       = snap.bloomPicks
            bedPicks         = snap.bedPicks
            postcode         = snap.postcode
            country          = snap.country
        } else if seedFirstGarden {
            // Legacy default — kept so existing callers that don't go through
            // the Setup wizard still get a usable garden to render against.
            let first = Garden(name: user.tier == .pro ? "My First Garden" : "My Garden")
            gardens          = [first]
            selectedGardenId = first.id
        }
    }

    // MARK: - Persistence

    private let defaults: UserDefaults
    private let storageKey: String
    private var isPersisting = false

    private struct Snapshot: Codable {
        var gardens: [Garden] = []
        var beds: [Bed] = []
        var selectedGardenId: UUID?
        var selectedBedId: UUID?
        var bloomPicks: [UUID: [Int: [String]]] = [:]
        var bedPicks:   [UUID: [Int: [String]]] = [:]
        var postcode: String = ""
        var country:  String = "GB"

        init(gardens: [Garden], beds: [Bed],
             selectedGardenId: UUID?, selectedBedId: UUID?,
             bloomPicks: [UUID: [Int: [String]]],
             bedPicks: [UUID: [Int: [String]]],
             postcode: String, country: String) {
            self.gardens = gardens
            self.beds = beds
            self.selectedGardenId = selectedGardenId
            self.selectedBedId = selectedBedId
            self.bloomPicks = bloomPicks
            self.bedPicks = bedPicks
            self.postcode = postcode
            self.country = country
        }

        // Custom decoder so snapshots written before `bedPicks` / `selectedBedId`
        // existed still load — otherwise existing users would lose their garden
        // on first launch with this build.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            gardens          = (try? c.decode([Garden].self, forKey: .gardens)) ?? []
            beds             = (try? c.decode([Bed].self,    forKey: .beds))    ?? []
            selectedGardenId = try? c.decodeIfPresent(UUID.self, forKey: .selectedGardenId)
            selectedBedId    = try? c.decodeIfPresent(UUID.self, forKey: .selectedBedId)
            bloomPicks       = (try? c.decode([UUID: [Int: [String]]].self, forKey: .bloomPicks)) ?? [:]
            bedPicks         = (try? c.decode([UUID: [Int: [String]]].self, forKey: .bedPicks))   ?? [:]
            postcode         = (try? c.decode(String.self, forKey: .postcode)) ?? ""
            country          = (try? c.decode(String.self, forKey: .country))  ?? "GB"
        }
    }

    private static func storageKey(for user: UserModel) -> String {
        "bm.gardenStore.snapshot.\(user.userId)"
    }

    private func persist() {
        // Avoid re-encoding during init's property assignments.
        guard !isPersisting else { return }
        let snap = Snapshot(gardens: gardens,
                            beds: beds,
                            selectedGardenId: selectedGardenId,
                            selectedBedId: selectedBedId,
                            bloomPicks: bloomPicks,
                            bedPicks: bedPicks,
                            postcode: postcode,
                            country: country)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        defaults.set(data, forKey: storageKey)
    }

    /// Wipes the persisted snapshot. Called from logout.
    public func resetLocalStorage() {
        defaults.removeObject(forKey: storageKey)
        gardens = []
        beds = []
        selectedGardenId = nil
        selectedBedId = nil
        bloomPicks = [:]
        bedPicks = [:]
        postcode = ""
        country = "GB"
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
        let bedIds = beds.filter { $0.gardenId == id }.map(\.id)
        gardens.removeAll { $0.id == id }
        beds.removeAll { $0.gardenId == id }
        bloomPicks.removeValue(forKey: id)
        for bid in bedIds { bedPicks.removeValue(forKey: bid) }
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
        if selectedBedId == nil, bed.gardenId == selectedGardenId {
            selectedBedId = bed.id
        }
    }

    public func updateBed(_ bed: Bed) {
        guard let idx = beds.firstIndex(where: { $0.id == bed.id }) else { return }
        beds[idx] = bed
    }

    public func deleteBed(id: UUID) {
        beds.removeAll { $0.id == id }
        bedPicks.removeValue(forKey: id)
        if selectedBedId == id { selectedBedId = bedsInSelectedGarden.first?.id }
    }

    public func bed(id: UUID) -> Bed? {
        beds.first(where: { $0.id == id })
    }

    public var selectedBed: Bed? {
        guard let bid = selectedBedId else { return nil }
        return bed(id: bid)
    }

    /// Resolves which bed should receive a Pro-tier pick. Defaults to the
    /// currently selected bed, falling back to the first bed in the
    /// selected garden if the selection is stale.
    public func effectiveBedIdForPicks() -> UUID? {
        if let bid = selectedBedId, bed(id: bid)?.gardenId == selectedGardenId { return bid }
        return bedsInSelectedGarden.first?.id
    }

    // MARK: - Bloom picks
    //
    // Tier rules:
    //   Free: picks live on the garden (`bloomPicks[gardenId][month]`).
    //   Pro : picks live on a bed (`bedPicks[bedId][month]`). Garden-level
    //         queries fold the picks across all of the selected garden's beds.
    //
    // The no-arg `picks(month:)` / `togglePick(plantId:month:)` route
    // automatically based on the user's tier and the currently-selected
    // bed (Pro). Pro callers that want to target a specific bed should use
    // the `bedId:` overloads explicitly.

    /// Plant IDs picked for `month` in the user's current scope. On Free this
    /// returns the garden's picks; on Pro it folds picks across every bed in
    /// the selected garden. Months are 1-indexed.
    public func picks(month: Int) -> [String] {
        switch user.tier {
        case .free:
            guard let gid = selectedGardenId else { return [] }
            return bloomPicks[gid]?[month] ?? []
        case .pro:
            guard let gid = selectedGardenId else { return [] }
            var merged: [String] = []
            for bid in beds.filter({ $0.gardenId == gid }).map(\.id) {
                merged.append(contentsOf: bedPicks[bid]?[month] ?? [])
            }
            return Array(NSOrderedSet(array: merged)) as? [String] ?? merged
        }
    }

    /// Plant IDs picked for `month` in a specific bed (Pro tier only).
    public func picks(month: Int, bedId: UUID) -> [String] {
        bedPicks[bedId]?[month] ?? []
    }

    public func togglePick(plantId: String, month: Int) {
        switch user.tier {
        case .free:
            guard let gid = selectedGardenId else { return }
            var byMonth = bloomPicks[gid] ?? [:]
            var list = byMonth[month] ?? []
            if let i = list.firstIndex(of: plantId) { list.remove(at: i) } else { list.append(plantId) }
            byMonth[month] = list.isEmpty ? nil : list
            bloomPicks[gid] = byMonth.isEmpty ? nil : byMonth
        case .pro:
            guard let bid = effectiveBedIdForPicks() else { return }
            togglePick(plantId: plantId, month: month, bedId: bid)
        }
    }

    /// Toggle a Pro-tier pick on a specific bed.
    public func togglePick(plantId: String, month: Int, bedId: UUID) {
        var byMonth = bedPicks[bedId] ?? [:]
        var list = byMonth[month] ?? []
        if let i = list.firstIndex(of: plantId) { list.remove(at: i) } else { list.append(plantId) }
        byMonth[month] = list.isEmpty ? nil : list
        bedPicks[bedId] = byMonth.isEmpty ? nil : byMonth
    }

    /// Whether `plantId` is currently picked for `month` in the active scope.
    public func isPicked(plantId: String, month: Int) -> Bool {
        switch user.tier {
        case .free:
            return picks(month: month).contains(plantId)
        case .pro:
            guard let bid = effectiveBedIdForPicks() else { return false }
            return bedPicks[bid]?[month]?.contains(plantId) ?? false
        }
    }

    public func removePick(plantId: String, month: Int) {
        switch user.tier {
        case .free:
            guard let gid = selectedGardenId else { return }
            bloomPicks[gid]?[month]?.removeAll { $0 == plantId }
            if bloomPicks[gid]?[month]?.isEmpty == true { bloomPicks[gid]?[month] = nil }
        case .pro:
            guard let bid = effectiveBedIdForPicks() else { return }
            bedPicks[bid]?[month]?.removeAll { $0 == plantId }
            if bedPicks[bid]?[month]?.isEmpty == true { bedPicks[bid]?[month] = nil }
        }
    }

    /// Convenience: month -> [Plant] resolved against the bundled library.
    /// Folds across beds on Pro tier.
    public func picksByMonth() -> [(month: Int, plants: [Plant])] {
        return (1...12).compactMap { m in
            let plants = picks(month: m).compactMap { PlantLibrary.plant(id: $0) }
            return plants.isEmpty ? nil : (m, plants)
        }
    }

    /// Pro-tier helper: month -> [Plant] for a single bed.
    public func picksByMonth(bedId: UUID) -> [(month: Int, plants: [Plant])] {
        let byMonth = bedPicks[bedId] ?? [:]
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

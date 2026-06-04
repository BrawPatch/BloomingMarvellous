import Foundation

// MARK: - TaskScheduler
//
// Pure helper that produces the canonical list of planting-schedule
// events for the user's current garden / bed picks. Mirrors the same
// id format and 12-weeks-before-bloom rules used by PlantingScheduleView
// so the two surfaces share completion state via `GardenStore.markTaskDone`.
//
// Home uses this to render a "Today's Tasks" card; PlantingScheduleView
// could (eventually) call this too instead of carrying its own copy.

public enum TaskScheduler {

    public struct Event: Identifiable, Hashable {
        public let id: String
        public let kind: ScheduleTaskKind
        public let month: Int          // 1-12
        public let day: Int            // 1 = start of window
        public let plantId: String
        public let plantName: String
        public let bloomMonth: Int
        public let gardenId: UUID
        public let gardenName: String
        public let bedId: UUID?        // nil on Free tier
        public let bedName: String?
    }

    /// All events across every garden / bed for the user's current picks.
    public static func allEvents(store: GardenStore,
                                 plantLookup: (String) -> Plant?) -> [Event] {
        switch store.user.tier {
        case .free: return freeTierEvents(store: store, plantLookup: plantLookup)
        case .pro:  return proTierEvents(store: store, plantLookup: plantLookup)
        }
    }

    /// Events scheduled for the given calendar month.
    public static func events(forMonth month: Int,
                              store: GardenStore,
                              plantLookup: (String) -> Plant?) -> [Event] {
        allEvents(store: store, plantLookup: plantLookup).filter { $0.month == month }
    }

    /// Outstanding (not yet done) events for the given month, sorted by
    /// kind then plant name so the order is stable.
    public static func outstandingEvents(forMonth month: Int,
                                         store: GardenStore,
                                         plantLookup: (String) -> Plant?) -> [Event] {
        events(forMonth: month, store: store, plantLookup: plantLookup)
            .filter { !store.isTaskDone(id: $0.id) }
            .sorted { (a, b) in
                if a.kind != b.kind {
                    return kindOrder(a.kind) < kindOrder(b.kind)
                }
                return a.plantName.localizedCompare(b.plantName) == .orderedAscending
            }
    }

    private static func kindOrder(_ k: ScheduleTaskKind) -> Int {
        switch k {
        case .sow:        return 0
        case .transplant: return 1
        case .harvest:    return 2
        }
    }

    // MARK: - Private generators

    private static func freeTierEvents(store: GardenStore,
                                       plantLookup: (String) -> Plant?) -> [Event] {
        var out: [Event] = []
        for garden in store.gardens {
            for bloomMonth in 1...12 {
                for plantId in store.picks(month: bloomMonth, gardenId: garden.id) {
                    out.append(contentsOf: events(forPlant: plantId,
                                                  bloomMonth: bloomMonth,
                                                  garden: garden,
                                                  bed: nil,
                                                  plantLookup: plantLookup))
                }
            }
        }
        return out
    }

    private static func proTierEvents(store: GardenStore,
                                      plantLookup: (String) -> Plant?) -> [Event] {
        var out: [Event] = []
        for bed in store.beds {
            guard let garden = store.garden(id: bed.gardenId) else { continue }
            for bloomMonth in 1...12 {
                for plantId in store.picks(month: bloomMonth, bedId: bed.id) {
                    out.append(contentsOf: events(forPlant: plantId,
                                                  bloomMonth: bloomMonth,
                                                  garden: garden,
                                                  bed: bed,
                                                  plantLookup: plantLookup))
                }
            }
        }
        return out
    }

    private static func events(forPlant plantId: String,
                               bloomMonth: Int,
                               garden: Garden,
                               bed: Bed?,
                               plantLookup: (String) -> Plant?) -> [Event] {
        guard let plant = plantLookup(plantId) else { return [] }
        let scopeId = bed?.id.uuidString ?? garden.id.uuidString
        var out: [Event] = []

        // Sow 12 weeks (~3 months) before the bloom month.
        let sowMonth = ((bloomMonth - 3 - 1) % 12 + 12) % 12 + 1
        out.append(Event(
            id: "sow|\(plantId)|\(bloomMonth)|\(scopeId)",
            kind: .sow, month: sowMonth, day: 1,
            plantId: plantId, plantName: plant.name, bloomMonth: bloomMonth,
            gardenId: garden.id, gardenName: garden.name,
            bedId: bed?.id, bedName: bed?.name))

        if let t = plant.transplantMonths.min() {
            out.append(Event(
                id: "trans|\(plantId)|\(bloomMonth)|\(scopeId)",
                kind: .transplant, month: t, day: 1,
                plantId: plantId, plantName: plant.name, bloomMonth: bloomMonth,
                gardenId: garden.id, gardenName: garden.name,
                bedId: bed?.id, bedName: bed?.name))
        }
        if let h = plant.harvestMonths.min() {
            out.append(Event(
                id: "harv|\(plantId)|\(bloomMonth)|\(scopeId)",
                kind: .harvest, month: h, day: 1,
                plantId: plantId, plantName: plant.name, bloomMonth: bloomMonth,
                gardenId: garden.id, gardenName: garden.name,
                bedId: bed?.id, bedName: bed?.name))
        }
        return out
    }
}

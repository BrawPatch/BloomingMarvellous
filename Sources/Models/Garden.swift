import Foundation

// MARK: - SoilType

public enum SoilType: String, Codable, CaseIterable, Identifiable, Equatable {
    case clay, loam, sandy, chalky, peaty, silty
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

// MARK: - Wetness

public enum Wetness: String, Codable, CaseIterable, Identifiable, Equatable {
    case soggy
    case normalPoor   = "normal_poor"
    case normalWell   = "normal_well"
    case slightlyDry  = "slightly_dry"
    case arid
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .soggy:        return "Soggy"
        case .normalPoor:   return "Normal (poor drainage)"
        case .normalWell:   return "Normal (well drained)"
        case .slightlyDry:  return "Slightly dry"
        case .arid:         return "Arid"
        }
    }
    public var shortLabel: String {
        switch self {
        case .soggy:        return "Soggy"
        case .normalPoor:   return "Normal–"
        case .normalWell:   return "Normal+"
        case .slightlyDry:  return "Slightly dry"
        case .arid:         return "Arid"
        }
    }
}

// MARK: - WeatherExposure

public enum WeatherExposure: String, Codable, CaseIterable, Identifiable, Equatable {
    case sheltered, normal, exposed
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

// MARK: - Sunlight

public enum Sunlight: String, Codable, CaseIterable, Identifiable, Equatable {
    case sunnyAlways  = "sunny_always"
    case sunnyAM      = "sunny_am"
    case sunnyPM      = "sunny_pm"
    case shadedAlways = "shaded_always"
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .sunnyAlways:  return "Sunny always"
        case .sunnyAM:      return "Sunny AM"
        case .sunnyPM:      return "Sunny PM"
        case .shadedAlways: return "Shaded always"
        }
    }
    public var shortLabel: String {
        switch self {
        case .sunnyAlways:  return "☀️ Full"
        case .sunnyAM:      return "🌤 AM"
        case .sunnyPM:      return "🌤 PM"
        case .shadedAlways: return "🌑 Shade"
        }
    }
}

// MARK: - SoilAcidity (pH bands)
//
// 5-band split of pH (0–14):
//   veryAcidic     (pH 0   – 4.0)
//   mildlyAcidic   (pH 4.0 – 5.5)
//   neutral        (pH 5.5 – 6.5)
//   mildlyAlkaline (pH 6.5 – 7.5)
//   veryAlkaline   (pH 7.5 – 14)
//
// Used for both the garden/bed setting and the plant's preferredAcidity
// list. A plant with an empty/nil acidity list is treated as
// "tolerates anything" by the matched filter.

public enum SoilAcidity: String, Codable, CaseIterable, Identifiable, Equatable {
    case veryAcidic     = "very_acidic"
    case mildlyAcidic   = "mildly_acidic"
    case neutral
    case mildlyAlkaline = "mildly_alkaline"
    case veryAlkaline   = "very_alkaline"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .veryAcidic:     return "Very acidic"
        case .mildlyAcidic:   return "Mildly acidic"
        case .neutral:        return "Neutral"
        case .mildlyAlkaline: return "Mildly alkaline"
        case .veryAlkaline:   return "Very alkaline"
        }
    }

    /// Compact label for tile badges.
    public var shortLabel: String {
        switch self {
        case .veryAcidic:     return "v.acid"
        case .mildlyAcidic:   return "acid"
        case .neutral:        return "neut"
        case .mildlyAlkaline: return "alk"
        case .veryAlkaline:   return "v.alk"
        }
    }

    /// Inclusive pH range that maps to this band.
    public var pHRange: ClosedRange<Double> {
        switch self {
        case .veryAcidic:     return 0.0...4.0
        case .mildlyAcidic:   return 4.0...5.5
        case .neutral:        return 5.5...6.5
        case .mildlyAlkaline: return 6.5...7.5
        case .veryAlkaline:   return 7.5...14.0
        }
    }

    /// Map a raw pH reading to a band. Returns nil for nonsense.
    public static func band(forPH pH: Double) -> SoilAcidity? {
        guard pH >= 0, pH <= 14 else { return nil }
        for band in SoilAcidity.allCases where band.pHRange.contains(pH) {
            return band
        }
        return nil
    }
}

// MARK: - BedStatus

public enum BedStatus: String, Codable, CaseIterable, Identifiable, Equatable {
    case planned, active
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

// MARK: - Garden

/// A single garden owned by the user. On Free tier, the user has exactly one
/// garden. The garden carries the default soil / wetness / exposure / sunlight
/// values that beds inherit unless they explicitly override.
public struct Garden: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var soilType: SoilType
    public var wetness: Wetness
    public var exposure: WeatherExposure
    public var sunlight: Sunlight
    // Optional so older persisted gardens still decode; nil = "not set",
    // which the Plant Picker treats as "don't filter on acidity".
    public var acidity: SoilAcidity?

    public init(id: UUID = UUID(),
                name: String,
                soilType: SoilType = .loam,
                wetness: Wetness = .normalWell,
                exposure: WeatherExposure = .normal,
                sunlight: Sunlight = .sunnyAlways,
                acidity: SoilAcidity? = .neutral) {
        self.id = id
        self.name = name
        self.soilType = soilType
        self.wetness = wetness
        self.exposure = exposure
        self.sunlight = sunlight
        self.acidity = acidity
    }
}

// MARK: - Bed

/// A planting bed inside a garden. Optional `*Override` fields let a bed
/// deviate from its garden's defaults. `effective…` accessors resolve the
/// final value the caller should display.
public struct Bed: Identifiable, Codable, Equatable {
    public var id: UUID
    public var gardenId: UUID
    public var name: String
    public var widthCm: Int
    public var lengthCm: Int
    public var status: BedStatus

    public var soilTypeOverride: SoilType?
    public var wetnessOverride: Wetness?
    public var exposureOverride: WeatherExposure?
    public var sunlightOverride: Sunlight?
    public var acidityOverride: SoilAcidity?

    /// Physical layout: how many of each plant (by id) are placed in this
    /// bed. Drives the Bed Planting Map's capacity model and grid render.
    /// Empty by default; pre-existing beds decode this as an empty dict.
    public var plantCounts: [String: Int]
    /// Plant ids that should be treated as perennials and carried over to
    /// the next planting season. Stored as `[String]` (not `Set`) so the
    /// JSON encoder produces a stable ordered array on disk.
    public var perennials: [String]
    /// Plant ids that have been carried over from a previous season —
    /// i.e. they were present when `startNewSeason` last ran and were
    /// marked as `perennials`. Used to surface the "Carried over from
    /// last year" badge in the bed crops list (Phase 5). Cleared when
    /// the species is removed from the bed.
    public var carriedOver: [String]
    /// Explicit (x, y) positions inside the bed for each placed plant.
    /// One PlantPlacement per individual specimen (so 3 lavenders generate
    /// 3 placements). Used by the drag-to-arrange Planting Map editor and
    /// is what the PDF print routes off when present. Empty array on
    /// older persisted beds.
    public var placements: [PlantPlacement]
    /// Archived snapshots of the bed at the end of each previous season,
    /// written by `startNewSeason`. The Bloom Planner / Bed Detail can
    /// scroll back through these read-only so the gardener remembers
    /// what they planted last year. Ordered newest-first.
    public var history: [SeasonSnapshot]

    public init(id: UUID = UUID(),
                gardenId: UUID,
                name: String,
                widthCm: Int,
                lengthCm: Int,
                status: BedStatus = .planned,
                soilTypeOverride: SoilType? = nil,
                wetnessOverride: Wetness? = nil,
                exposureOverride: WeatherExposure? = nil,
                sunlightOverride: Sunlight? = nil,
                acidityOverride: SoilAcidity? = nil,
                plantCounts: [String: Int] = [:],
                perennials: [String] = [],
                carriedOver: [String] = [],
                placements: [PlantPlacement] = [],
                history: [SeasonSnapshot] = []) {
        self.id = id
        self.gardenId = gardenId
        self.name = name
        self.widthCm = widthCm
        self.lengthCm = lengthCm
        self.status = status
        self.soilTypeOverride = soilTypeOverride
        self.wetnessOverride = wetnessOverride
        self.exposureOverride = exposureOverride
        self.sunlightOverride = sunlightOverride
        self.acidityOverride = acidityOverride
        self.plantCounts = plantCounts
        self.perennials = perennials
        self.carriedOver = carriedOver
        self.placements = placements
        self.history = history
    }

    private enum CodingKeys: String, CodingKey {
        case id, gardenId, name, widthCm, lengthCm, status
        case soilTypeOverride, wetnessOverride, exposureOverride, sunlightOverride, acidityOverride
        case plantCounts, perennials, carriedOver, placements, history
    }

    /// Custom decode so existing persisted beds (which predate the
    /// `plantCounts` / `perennials` / `placements` fields) keep loading
    /// cleanly. The synthesised init(from:) treats missing required
    /// fields as fatal — not what we want for an additive schema bump.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self, forKey: .id)
        gardenId         = try c.decode(UUID.self, forKey: .gardenId)
        name             = try c.decode(String.self, forKey: .name)
        widthCm          = try c.decode(Int.self, forKey: .widthCm)
        lengthCm         = try c.decode(Int.self, forKey: .lengthCm)
        status           = try c.decode(BedStatus.self, forKey: .status)
        soilTypeOverride = try c.decodeIfPresent(SoilType.self, forKey: .soilTypeOverride)
        wetnessOverride  = try c.decodeIfPresent(Wetness.self, forKey: .wetnessOverride)
        exposureOverride = try c.decodeIfPresent(WeatherExposure.self, forKey: .exposureOverride)
        sunlightOverride = try c.decodeIfPresent(Sunlight.self, forKey: .sunlightOverride)
        acidityOverride  = try c.decodeIfPresent(SoilAcidity.self, forKey: .acidityOverride)
        plantCounts      = try c.decodeIfPresent([String: Int].self, forKey: .plantCounts) ?? [:]
        perennials       = try c.decodeIfPresent([String].self, forKey: .perennials) ?? []
        carriedOver      = try c.decodeIfPresent([String].self, forKey: .carriedOver) ?? []
        placements       = try c.decodeIfPresent([PlantPlacement].self, forKey: .placements) ?? []
        history          = try c.decodeIfPresent([SeasonSnapshot].self, forKey: .history) ?? []
    }

    public var overridesGarden: Bool {
        soilTypeOverride != nil
        || wetnessOverride != nil
        || exposureOverride != nil
        || sunlightOverride != nil
        || acidityOverride != nil
    }

    public func effectiveSoil(garden: Garden)     -> SoilType         { soilTypeOverride  ?? garden.soilType }
    public func effectiveWetness(garden: Garden)  -> Wetness          { wetnessOverride   ?? garden.wetness }
    public func effectiveExposure(garden: Garden) -> WeatherExposure  { exposureOverride  ?? garden.exposure }
    public func effectiveSunlight(garden: Garden) -> Sunlight         { sunlightOverride  ?? garden.sunlight }
    public func effectiveAcidity(garden: Garden)  -> SoilAcidity?     { acidityOverride   ?? garden.acidity }

    public var dimensionLabel: String { "\(widthCm) × \(lengthCm) cm" }

    /// Unit-aware label used by Bed list rows / detail header. Falls back
    /// to `dimensionLabel` (cm) for callers that haven't been threaded
    /// through the user's preference yet.
    public func dimensionLabel(unit: LengthUnit) -> String {
        LengthFormat.dimensions(widthCm: widthCm, lengthCm: lengthCm, unit: unit)
    }
}

// MARK: - PlantPlacement
//
// One specimen positioned inside a Bed. Three lavenders in a row are three
// PlantPlacement values, each with its own (xCm, yCm) in bed-local
// coordinates (origin top-left, x right, y down). Persists across seasons
// when `isPerennial == true`; annual placements clear out on
// startNewSeason. `plantedYear` is the calendar year the placement was
// originally created so the Planting Map can show "2nd year" badges and
// the season-rotation helper can age placements correctly.

// MARK: - CustomReminder
//
// Gardener-authored to-do that lives alongside the auto-generated
// sow/transplant/harvest tasks. Surfaced on Home's "Today's Tasks"
// panel and on the Bloom Planner calendar for the matching month, with
// the same checkbox machinery (id-keyed completion state on
// GardenStore). Optional `bedId` lets the gardener pin a reminder to a
// specific bed; optional `plantId` links it to a plant page.

public struct CustomReminder: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var title: String
    public var date: Date
    public var bedId: UUID?
    public var plantId: String?

    public init(id: UUID = UUID(),
                title: String,
                date: Date,
                bedId: UUID? = nil,
                plantId: String? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.bedId = bedId
        self.plantId = plantId
    }

    /// Stable id used by GardenStore.completedTaskIds so a reminder's
    /// done-state is in the same set as the generated sow/etc tasks.
    public var taskId: String { "reminder|\(id.uuidString)" }
}

// MARK: - SeasonSnapshot
//
// Frozen record of a bed at the end of a planting season — written by
// `GardenStore.startNewSeason` before annuals are stripped from the
// active state. Lets the gardener scroll back through prior years on
// the Bloom Planner and Bed Detail to remember what they planted.
//
// `year` and `endedOn` together identify the snapshot. `plantCounts`,
// `perennials`, `carriedOver` and `placements` mirror the matching
// fields on Bed at the moment the season ended — including counts
// (item 1: persist the NUMBER of each annual, not just the species).
//
// Stored newest-first; `endedOn` orders entries within the same year.

public struct SeasonSnapshot: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var year: Int
    public var endedOn: Date
    public var plantCounts: [String: Int]
    public var perennials: [String]
    public var carriedOver: [String]
    public var placements: [PlantPlacement]

    public init(id: UUID = UUID(),
                year: Int,
                endedOn: Date,
                plantCounts: [String: Int],
                perennials: [String],
                carriedOver: [String],
                placements: [PlantPlacement]) {
        self.id = id
        self.year = year
        self.endedOn = endedOn
        self.plantCounts = plantCounts
        self.perennials = perennials
        self.carriedOver = carriedOver
        self.placements = placements
    }

    /// IDs of annual placements specifically (perennials carry forward
    /// into the new season, so a layout editor doesn't need to "reserve"
    /// their spots — they ARE still there). Item 6 uses this to ghost
    /// last year's annual footprints as locked reserved zones until the
    /// gardener clears them or replants on top.
    public var annualPlacements: [PlantPlacement] {
        placements.filter { !$0.isPerennial }
    }
}

public struct PlantPlacement: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var plantId: String
    public var xCm: Double
    public var yCm: Double
    public var isPerennial: Bool
    public var plantedYear: Int

    public init(id: UUID = UUID(),
                plantId: String,
                xCm: Double,
                yCm: Double,
                isPerennial: Bool = false,
                plantedYear: Int = Calendar.current.component(.year, from: Date())) {
        self.id = id
        self.plantId = plantId
        self.xCm = xCm
        self.yCm = yCm
        self.isPerennial = isPerennial
        self.plantedYear = plantedYear
    }
}

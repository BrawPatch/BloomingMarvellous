import Foundation

// MARK: - PlantType

public enum PlantType: String, Codable, CaseIterable, Identifiable, Equatable {
    case annual, perennial, biennial, bulb, shrub, herb, vegetable
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

// MARK: - SowMethod

public enum SowMethod: String, Codable, CaseIterable, Equatable {
    case startIndoors  = "start_indoors"
    case directSow     = "direct_sow"
    case transplant    = "transplant"

    public var label: String {
        switch self {
        case .startIndoors: return "Start indoors"
        case .directSow:    return "Direct sow"
        case .transplant:   return "Transplant"
        }
    }
}

// MARK: - Plant
//
// Rich plant record consumed by the Plant Picker, Bloom Schedule, and
// Planting Schedule. Months are 1-indexed (1 = January). Multi-month
// windows allow seasonal hints (e.g. "sow Mar–May" → [3, 4, 5]).
public struct Plant: Identifiable, Codable, Equatable {

    public var id: String
    public var name: String
    public var latin: String
    public var type: PlantType
    public var heightCm: Int?
    public var colorHex: String?

    // Bloom + lifecycle windows (1-indexed months)
    public var bloomMonths:       [Int]
    public var sowIndoorMonths:   [Int]
    public var sowDirectMonths:   [Int]
    public var transplantMonths:  [Int]
    public var harvestMonths:     [Int]

    // Preferences
    public var preferredSoil:     [SoilType]
    public var preferredSunlight: [Sunlight]
    // Optional so old payloads still decode; nil/empty = no preference
    // (the matched filter treats that as "tolerates anything").
    public var preferredAcidity:  [SoilAcidity]?
    public var preferredWetness:  [Wetness]?

    // Structured sowing details — surfaced in the Plant Detail "Sowing
    // details" card. All optional; the free-text `germinationRequirements`
    // remains the fallback narrative when these are absent.
    public var seedDepthMm:         Int?
    public var germinationTempC:    Int?
    public var germinationDays:     String?
    public var lightForGermination: String?

    // Editorial copy
    /// Narrative description of the plant (typically a Wikipedia summary).
    /// Optional so older payloads keep decoding.
    public var description: String?
    /// Bulleted, actionable grower's tips — should be short and per-cultivar
    /// where possible, family-level otherwise. One bullet per `\n`.
    public var growersTips: String
    public var germinationRequirements: String

    // Companion suggestions (other plant IDs)
    public var companions: [String]

    // Access tier — matches the existing /v1/data `access` field.
    // "free" | "pro" | "pack_exotic" | "pack_edible"
    public var access: String

    // Affiliate / purchase link (Amazon stub).
    public var buyLink: URL?

    // Photographic image (Wikimedia Commons hosted, sourced by Latin name
    // from the ingest pipeline). Optional — older library payloads may omit.
    public var imageUrl: URL?

    public init(id: String,
                name: String,
                latin: String,
                type: PlantType,
                heightCm: Int? = nil,
                colorHex: String? = nil,
                bloomMonths: [Int] = [],
                sowIndoorMonths: [Int] = [],
                sowDirectMonths: [Int] = [],
                transplantMonths: [Int] = [],
                harvestMonths: [Int] = [],
                preferredSoil: [SoilType] = [],
                preferredSunlight: [Sunlight] = [],
                preferredAcidity: [SoilAcidity]? = nil,
                preferredWetness: [Wetness]? = nil,
                seedDepthMm: Int? = nil,
                germinationTempC: Int? = nil,
                germinationDays: String? = nil,
                lightForGermination: String? = nil,
                description: String? = nil,
                growersTips: String = "",
                germinationRequirements: String = "",
                companions: [String] = [],
                access: String = "free",
                buyLink: URL? = nil,
                imageUrl: URL? = nil) {
        self.id = id
        self.name = name
        self.latin = latin
        self.type = type
        self.heightCm = heightCm
        self.colorHex = colorHex
        self.bloomMonths = bloomMonths
        self.sowIndoorMonths = sowIndoorMonths
        self.sowDirectMonths = sowDirectMonths
        self.transplantMonths = transplantMonths
        self.harvestMonths = harvestMonths
        self.preferredSoil = preferredSoil
        self.preferredSunlight = preferredSunlight
        self.preferredAcidity = preferredAcidity
        self.preferredWetness = preferredWetness
        self.seedDepthMm = seedDepthMm
        self.germinationTempC = germinationTempC
        self.germinationDays = germinationDays
        self.lightForGermination = lightForGermination
        self.description = description
        self.growersTips = growersTips
        self.germinationRequirements = germinationRequirements
        self.companions = companions
        self.access = access
        self.buyLink = buyLink
        self.imageUrl = imageUrl
    }

    public func blooms(in month: Int) -> Bool { bloomMonths.contains(month) }

    public func sowMethods(in month: Int) -> [SowMethod] {
        var methods: [SowMethod] = []
        if sowIndoorMonths.contains(month)  { methods.append(.startIndoors) }
        if sowDirectMonths.contains(month)  { methods.append(.directSow) }
        if transplantMonths.contains(month) { methods.append(.transplant) }
        return methods
    }
}

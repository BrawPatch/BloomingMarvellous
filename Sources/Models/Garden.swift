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

    public init(id: UUID = UUID(),
                name: String,
                soilType: SoilType = .loam,
                wetness: Wetness = .normalWell,
                exposure: WeatherExposure = .normal,
                sunlight: Sunlight = .sunnyAlways) {
        self.id = id
        self.name = name
        self.soilType = soilType
        self.wetness = wetness
        self.exposure = exposure
        self.sunlight = sunlight
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

    public init(id: UUID = UUID(),
                gardenId: UUID,
                name: String,
                widthCm: Int,
                lengthCm: Int,
                status: BedStatus = .planned,
                soilTypeOverride: SoilType? = nil,
                wetnessOverride: Wetness? = nil,
                exposureOverride: WeatherExposure? = nil,
                sunlightOverride: Sunlight? = nil) {
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
    }

    public var overridesGarden: Bool {
        soilTypeOverride != nil
        || wetnessOverride != nil
        || exposureOverride != nil
        || sunlightOverride != nil
    }

    public func effectiveSoil(garden: Garden)     -> SoilType         { soilTypeOverride  ?? garden.soilType }
    public func effectiveWetness(garden: Garden)  -> Wetness          { wetnessOverride   ?? garden.wetness }
    public func effectiveExposure(garden: Garden) -> WeatherExposure  { exposureOverride  ?? garden.exposure }
    public func effectiveSunlight(garden: Garden) -> Sunlight         { sunlightOverride  ?? garden.sunlight }

    public var dimensionLabel: String { "\(widthCm) × \(lengthCm) cm" }
}

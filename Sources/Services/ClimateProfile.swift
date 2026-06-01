import Foundation

// MARK: - ClimateProfile
//
// Coarse postcode → climate mapping used to bias the Plant Picker. Maps a
// UK postcode area (the leading letters of an outward code, e.g. "EH",
// "SW", "IV") to a `Region` and a derived growing season (the months a
// typical hardy garden plant can realistically be in bloom outdoors).
//
// Not weather data — for now it's a deliberately small static table so
// the picker has something useful to filter on. Swap with a real
// climate / hardiness API later by replacing `lookup(postcode:)`.

public struct ClimateProfile: Equatable {
    public enum Region: String, CaseIterable {
        case scotlandHighlands  // AB IV KW PH
        case scotlandCentral    // G EH KY FK KA PA DD DG ML TD
        case northEngland       // BD BL CA DH DL DN HD HG HU HX LA LN LS NE PR S SK SR TS WF WN YO
        case midlands           // B CV DE LE NG NN ST TF WR WS WV
        case wales              // CF CH LD LL NP SA SY
        case southWest          // BA BS DT EX GL PL TA TQ TR
        case southEast          // AL BN BR CB CM CO CR CT DA EN GU HA HP IG IP KT LU ME MK NR OX PE PO RG RH RM SG SL SM SO SS TN TW UB WD
        case london             // E EC N NW SE SW W WC
        case northernIreland    // BT
        case unknown

        public var label: String {
            switch self {
            case .scotlandHighlands: return "Scottish Highlands"
            case .scotlandCentral:   return "Scotland — Central"
            case .northEngland:      return "North England"
            case .midlands:          return "Midlands"
            case .wales:             return "Wales"
            case .southWest:         return "South-West England"
            case .southEast:         return "South-East England"
            case .london:            return "London"
            case .northernIreland:   return "Northern Ireland"
            case .unknown:           return "Unknown"
            }
        }

        /// Months (1–12) when bloom outdoors is realistic.
        public var growingSeason: Set<Int> {
            switch self {
            case .scotlandHighlands:                  return [5, 6, 7, 8, 9]
            case .scotlandCentral, .northEngland:     return [4, 5, 6, 7, 8, 9, 10]
            case .midlands, .wales:                   return [3, 4, 5, 6, 7, 8, 9, 10]
            case .southWest, .southEast, .london:     return [3, 4, 5, 6, 7, 8, 9, 10, 11]
            case .northernIreland:                    return [4, 5, 6, 7, 8, 9, 10]
            case .unknown:                            return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
            }
        }

        /// A short hardiness hint to surface in the picker.
        public var hardinessLabel: String {
            switch self {
            case .scotlandHighlands:                  return "Cold · short season"
            case .scotlandCentral, .northEngland:     return "Cool · moderate season"
            case .midlands, .wales:                   return "Mild · long season"
            case .southWest, .southEast, .london:     return "Warm · long season"
            case .northernIreland:                    return "Mild · damp"
            case .unknown:                            return "Region not set"
            }
        }
    }

    public let region: Region
    public let postcode: String

    public var growingSeason: Set<Int>  { region.growingSeason }
    public var hardinessLabel: String   { region.hardinessLabel }
    public var regionLabel: String      { region.label }

    public init(region: Region, postcode: String) {
        self.region = region
        self.postcode = postcode
    }

    /// Resolve a postcode to a region. Accepts the full postcode or just
    /// the outward part (e.g. "EH3", "EH3 9XX"); only the leading letters
    /// (the postcode area) are used.
    public static func lookup(postcode raw: String?) -> ClimateProfile {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return ClimateProfile(region: .unknown, postcode: "") }
        let area = String(trimmed.prefix { $0.isLetter })
        guard !area.isEmpty else { return ClimateProfile(region: .unknown, postcode: trimmed) }
        let region = Self.area(area)
        return ClimateProfile(region: region, postcode: trimmed)
    }

    private static func area(_ a: String) -> Region {
        // Order matters: longer area codes (BT, IV, etc.) match before
        // their single-letter counterparts.
        switch a {
        case "AB", "IV", "KW", "PH":                                                                    return .scotlandHighlands
        case "G", "EH", "KY", "FK", "KA", "PA", "DD", "DG", "ML", "TD":                                  return .scotlandCentral
        case "BD","BL","CA","DH","DL","DN","HD","HG","HU","HX","LA","LN","LS",
             "NE","PR","S","SK","SR","TS","WF","WN","YO":                                                return .northEngland
        case "B","CV","DE","LE","NG","NN","ST","TF","WR","WS","WV":                                     return .midlands
        case "CF","CH","LD","LL","NP","SA","SY":                                                        return .wales
        case "BA","BS","DT","EX","GL","PL","TA","TQ","TR":                                              return .southWest
        case "AL","BN","BR","CB","CM","CO","CR","CT","DA","EN","GU","HA","HP","IG",
             "IP","KT","LU","ME","MK","NR","OX","PE","PO","RG","RH","RM","SG","SL",
             "SM","SO","SS","TN","TW","UB","WD":                                                        return .southEast
        case "E","EC","N","NW","SE","SW","W","WC":                                                      return .london
        case "BT":                                                                                      return .northernIreland
        default:                                                                                        return .unknown
        }
    }
}

// MARK: - Plant climate match

public extension ClimateProfile {
    /// Whether the plant's bloom window intersects the region's growing season.
    func suits(_ plant: Plant) -> Bool {
        guard region != .unknown else { return true }
        if plant.bloomMonths.isEmpty { return true } // foliage / herb — no bloom gate
        return !Set(plant.bloomMonths).isDisjoint(with: growingSeason)
    }
}

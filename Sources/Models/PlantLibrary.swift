import Foundation

// MARK: - PlantLibrary
//
// Bundled sample library. Once the backend exposes a structured
// `/v1/library` payload (see TODO at the bottom of the file) this constant
// becomes a fallback for offline mode; until then it powers the Plant
// Picker and Bloom / Planting Schedule end-to-end.

public enum PlantLibrary {

    public static let all: [Plant] = [
        // ── Free tier ────────────────────────────────────────────────────────
        Plant(id: "lavender", name: "Lavender", latin: "Lavandula angustifolia",
              type: .perennial, heightCm: 60, colorHex: "#b8a0d8",
              bloomMonths: [6, 7, 8],
              sowIndoorMonths: [3, 4], sowDirectMonths: [4, 5],
              transplantMonths: [5, 6], harvestMonths: [7, 8],
              preferredSoil: [.loam, .sandy, .chalky],
              preferredSunlight: [.sunnyAlways, .sunnyPM],
              growersTips: "Prefers free-draining soil and full sun. Prune after flowering to keep compact.",
              germinationRequirements: "Light required. Surface-sow at 18–22°C. 14–21 days.",
              companions: ["marigold"],
              access: "free"),

        Plant(id: "sunflower", name: "Sunflower", latin: "Helianthus annuus",
              type: .annual, heightCm: 200, colorHex: "#e8b070",
              bloomMonths: [7, 8, 9],
              sowIndoorMonths: [3, 4], sowDirectMonths: [4, 5],
              transplantMonths: [5], harvestMonths: [9, 10],
              preferredSoil: [.loam, .sandy],
              preferredSunlight: [.sunnyAlways],
              growersTips: "Deep watering once a week. Stake tall varieties.",
              germinationRequirements: "Sow 2 cm deep at 18–24°C. 7–14 days.",
              companions: ["cosmos"],
              access: "free"),

        Plant(id: "cosmos", name: "Cosmos", latin: "Cosmos bipinnatus",
              type: .annual, heightCm: 90, colorHex: "#f0a898",
              bloomMonths: [6, 7, 8, 9, 10],
              sowIndoorMonths: [3, 4], sowDirectMonths: [4, 5],
              transplantMonths: [5, 6], harvestMonths: [],
              preferredSoil: [.loam, .sandy],
              preferredSunlight: [.sunnyAlways, .sunnyPM],
              growersTips: "Deadhead regularly for continuous bloom. Tolerates poor soil.",
              germinationRequirements: "Sow 5 mm deep at 18°C. 7–10 days.",
              companions: ["sunflower"],
              access: "free"),

        Plant(id: "sweet-pea", name: "Sweet Pea", latin: "Lathyrus odoratus",
              type: .annual, heightCm: 200, colorHex: "#c0a0d8",
              bloomMonths: [5, 6, 7, 8],
              sowIndoorMonths: [10, 11, 1, 2], sowDirectMonths: [3, 4],
              transplantMonths: [4, 5], harvestMonths: [],
              preferredSoil: [.loam],
              preferredSunlight: [.sunnyAlways],
              growersTips: "Provide trellis or canes. Pinch tips to encourage branching.",
              germinationRequirements: "Soak seed 24h. Sow 2 cm deep at 15°C. 10–21 days.",
              companions: [],
              access: "free"),

        Plant(id: "marigold", name: "Marigold", latin: "Tagetes patula",
              type: .annual, heightCm: 30, colorHex: "#f4b8b0",
              bloomMonths: [5, 6, 7, 8, 9, 10],
              sowIndoorMonths: [3, 4], sowDirectMonths: [4, 5],
              transplantMonths: [5], harvestMonths: [],
              preferredSoil: [.loam, .sandy],
              preferredSunlight: [.sunnyAlways],
              growersTips: "Great companion for tomatoes — repels aphids and whitefly.",
              germinationRequirements: "Sow 5 mm deep at 18–22°C. 5–10 days.",
              companions: ["lavender"],
              access: "free"),

        Plant(id: "nasturtium", name: "Nasturtium", latin: "Tropaeolum majus",
              type: .annual, heightCm: 30, colorHex: "#e8b070",
              bloomMonths: [6, 7, 8, 9],
              sowIndoorMonths: [3, 4], sowDirectMonths: [4, 5, 6],
              transplantMonths: [], harvestMonths: [],
              preferredSoil: [.loam, .sandy],
              preferredSunlight: [.sunnyAlways, .sunnyPM],
              growersTips: "Edible flowers and leaves. Thrives in poor soil.",
              germinationRequirements: "Sow 1.5 cm deep at 13–18°C. 7–14 days.",
              companions: [],
              access: "free"),

        // ── Pro tier ─────────────────────────────────────────────────────────
        Plant(id: "delphinium", name: "Delphinium", latin: "Delphinium elatum",
              type: .perennial, heightCm: 180, colorHex: "#88c8e0",
              bloomMonths: [6, 7, 8],
              sowIndoorMonths: [2, 3], sowDirectMonths: [],
              transplantMonths: [5], harvestMonths: [],
              preferredSoil: [.loam],
              preferredSunlight: [.sunnyAlways, .sunnyPM],
              growersTips: "Stake stems before they flop. Cut back after first flush for second flowering.",
              germinationRequirements: "Sow 5 mm deep at 13–15°C in dark. 14–28 days.",
              companions: ["peony"],
              access: "pro"),

        Plant(id: "foxglove", name: "Foxglove", latin: "Digitalis purpurea",
              type: .biennial, heightCm: 150, colorHex: "#b8a0d8",
              bloomMonths: [6, 7],
              sowIndoorMonths: [5, 6, 7], sowDirectMonths: [6, 7],
              transplantMonths: [9], harvestMonths: [],
              preferredSoil: [.loam, .peaty],
              preferredSunlight: [.sunnyPM, .shadedAlways],
              growersTips: "Self-seeds prolifically. All parts toxic — handle with gloves.",
              germinationRequirements: "Surface-sow at 18–20°C. Light required. 14–21 days.",
              companions: [],
              access: "pro"),

        Plant(id: "dahlia", name: "Dahlia", latin: "Dahlia pinnata",
              type: .bulb, heightCm: 120, colorHex: "#f0a898",
              bloomMonths: [7, 8, 9, 10],
              sowIndoorMonths: [], sowDirectMonths: [],
              transplantMonths: [4, 5], harvestMonths: [],
              preferredSoil: [.loam],
              preferredSunlight: [.sunnyAlways, .sunnyPM],
              growersTips: "Lift tubers after first frost in cold areas. Pinch tips at 30 cm.",
              germinationRequirements: "Tubers, not seeds. Start indoors Mar, plant out after last frost.",
              companions: [],
              access: "pro"),

        Plant(id: "peony", name: "Peony", latin: "Paeonia lactiflora",
              type: .perennial, heightCm: 90, colorHex: "#f4b8b0",
              bloomMonths: [5, 6],
              sowIndoorMonths: [], sowDirectMonths: [],
              transplantMonths: [10, 11, 3], harvestMonths: [],
              preferredSoil: [.loam],
              preferredSunlight: [.sunnyAlways, .sunnyPM],
              growersTips: "Plant crown shallow — 3 cm below soil. Don't move once established.",
              germinationRequirements: "Bare-root tubers, plant Oct–Nov or Mar.",
              companions: ["delphinium"],
              access: "pro"),

        Plant(id: "hellebore", name: "Hellebore", latin: "Helleborus orientalis",
              type: .perennial, heightCm: 45, colorHex: "#c0a0d8",
              bloomMonths: [1, 2, 3, 4],
              sowIndoorMonths: [], sowDirectMonths: [9],
              transplantMonths: [9, 10], harvestMonths: [],
              preferredSoil: [.loam, .chalky],
              preferredSunlight: [.sunnyPM, .shadedAlways],
              growersTips: "Cut old leaves in late winter to show flowers. Mulch annually.",
              germinationRequirements: "Sow fresh seed; needs cold period. 6–12 months.",
              companions: [],
              access: "pro"),

        Plant(id: "echinacea", name: "Echinacea", latin: "Echinacea purpurea",
              type: .perennial, heightCm: 90, colorHex: "#c0a0d8",
              bloomMonths: [7, 8, 9],
              sowIndoorMonths: [3, 4], sowDirectMonths: [5],
              transplantMonths: [5, 6], harvestMonths: [],
              preferredSoil: [.loam, .sandy],
              preferredSunlight: [.sunnyAlways],
              growersTips: "Leave seed heads for goldfinches in autumn.",
              germinationRequirements: "Sow 5 mm at 18°C. 10–21 days.",
              companions: [],
              access: "pro"),

        // ── Pack: Exotic ─────────────────────────────────────────────────────
        Plant(id: "phalaenopsis", name: "Phalaenopsis Orchid", latin: "Phalaenopsis hybrid",
              type: .perennial, heightCm: 40, colorHex: "#f4b8b0",
              bloomMonths: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
              sowIndoorMonths: [], sowDirectMonths: [],
              transplantMonths: [4, 5], harvestMonths: [],
              preferredSoil: [.peaty],
              preferredSunlight: [.sunnyAM, .sunnyPM],
              growersTips: "Indoors only. Water weekly, fortnightly in winter. Re-pot every 2 years.",
              germinationRequirements: "Buy as nursery plant; seed propagation requires lab conditions.",
              companions: [],
              access: "pack_exotic"),

        Plant(id: "bird-of-paradise", name: "Bird of Paradise", latin: "Strelitzia reginae",
              type: .perennial, heightCm: 200, colorHex: "#e8b070",
              bloomMonths: [9, 10, 11, 12, 1, 2],
              sowIndoorMonths: [3, 4], sowDirectMonths: [],
              transplantMonths: [5], harvestMonths: [],
              preferredSoil: [.loam],
              preferredSunlight: [.sunnyAlways],
              growersTips: "Heated greenhouse or conservatory in the UK. Min 10°C overnight.",
              germinationRequirements: "Soak seed 48h, sow at 25°C. Slow — 1–6 months.",
              companions: [],
              access: "pack_exotic"),

        // ── Pack: Edible ─────────────────────────────────────────────────────
        Plant(id: "tomato-gardener", name: "Tomato 'Gardener's Delight'", latin: "Solanum lycopersicum",
              type: .vegetable, heightCm: 180, colorHex: "#e07070",
              bloomMonths: [6, 7, 8],
              sowIndoorMonths: [2, 3, 4], sowDirectMonths: [],
              transplantMonths: [5, 6], harvestMonths: [7, 8, 9, 10],
              preferredSoil: [.loam],
              preferredSunlight: [.sunnyAlways],
              growersTips: "Pinch out side shoots on cordon varieties. Feed weekly once fruit sets.",
              germinationRequirements: "Sow 5 mm at 21°C. 7–10 days.",
              companions: ["marigold"],
              access: "pack_edible"),

        Plant(id: "courgette", name: "Courgette", latin: "Cucurbita pepo",
              type: .vegetable, heightCm: 60, colorHex: "#7aaa8a",
              bloomMonths: [6, 7, 8, 9],
              sowIndoorMonths: [4, 5], sowDirectMonths: [5, 6],
              transplantMonths: [6], harvestMonths: [7, 8, 9],
              preferredSoil: [.loam],
              preferredSunlight: [.sunnyAlways],
              growersTips: "One plant feeds a family. Harvest at 15 cm for best flavour.",
              germinationRequirements: "Sow 2 cm at 21°C. 5–10 days.",
              companions: ["nasturtium"],
              access: "pack_edible"),

        Plant(id: "basil", name: "Basil", latin: "Ocimum basilicum",
              type: .herb, heightCm: 30, colorHex: "#7aaa8a",
              bloomMonths: [],
              sowIndoorMonths: [3, 4, 5], sowDirectMonths: [5, 6],
              transplantMonths: [5, 6], harvestMonths: [6, 7, 8, 9],
              preferredSoil: [.loam],
              preferredSunlight: [.sunnyAlways, .sunnyPM],
              growersTips: "Pinch flowering tips to keep leaves coming. Companion to tomato.",
              germinationRequirements: "Surface-sow at 21°C. Light required. 5–10 days.",
              companions: ["tomato-gardener"],
              access: "pack_edible"),
    ]

    public static func plant(id: String) -> Plant? { all.first(where: { $0.id == id }) }

    /// Server-side filter mirror, kept here so the client can preview which
    /// plants the user is entitled to without an extra network call.
    public static func entitled(for user: UserModel) -> [Plant] {
        let packs = Set(user.purchasedPacks.map { $0.rawValue })
        return all.filter { p in
            switch p.access {
            case "free": return true
            case "pro":  return user.tier == .pro
            default:     return user.tier == .pro && packs.contains(p.access)
            }
        }
    }
}

// MARK: - Backend follow-up
//
// The eventual `/v1/library` endpoint should return the same Plant payload
// (Codable). For now the bundled library above is the source of truth so
// the Plant Picker / schedule features work end-to-end without a Lambda
// schema change.

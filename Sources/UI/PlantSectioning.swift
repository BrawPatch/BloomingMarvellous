#if canImport(UIKit)
import SwiftUI
import BloomingMarvellous

// MARK: - PlantGroup
//
// User-facing plant category — broader than Plant.PlantType so a
// gallery row can read "Flowers" instead of seven separate "Annual,
// Perennial, Biennial, Bulb, Shrub…" sections. Fruit isn't a native
// PlantType case, so we infer it from the plant's access tag
// (everything tagged pack_fruit lands under Fruit).

public enum PlantGroup: String, CaseIterable, Identifiable, Hashable {
    case flower
    case vegetable
    case herb
    case fruit

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .flower:    return "Flowers"
        case .vegetable: return "Vegetables"
        case .herb:      return "Herbs"
        case .fruit:     return "Fruit"
        }
    }

    public var emoji: String {
        switch self {
        case .flower:    return "🌸"
        case .vegetable: return "🥕"
        case .herb:      return "🌿"
        case .fruit:     return "🍓"
        }
    }

    /// Assigns a plant to a user-facing group. Fruit takes precedence
    /// (pack_fruit access wins regardless of type); the kitchen-garden
    /// PlantType cases follow; everything else is a flower.
    public static func group(for plant: Plant) -> PlantGroup {
        if plant.access == "pack_fruit" { return .fruit }
        switch plant.type {
        case .vegetable: return .vegetable
        case .herb:      return .herb
        case .annual, .perennial, .biennial, .bulb, .shrub:
            return .flower
        }
    }
}

// MARK: - PlantSection
//
// One header + plants block. Used by every gallery surface to render
// `[Type] → [Genus] → [Common Name]` consistently.

public struct PlantSection: Identifiable {
    public let group: PlantGroup
    public let plants: [Plant]
    public var id: String { group.rawValue }
    public init(group: PlantGroup, plants: [Plant]) {
        self.group = group
        self.plants = plants
    }
}

public enum PlantSectioning {

    /// Filter plants by free-text search. Matches case-insensitive
    /// substring against both common name and Latin binomial.
    public static func filter(_ plants: [Plant], search rawSearch: String) -> [Plant] {
        let q = rawSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return plants }
        return plants.filter { p in
            p.name.lowercased().contains(q) || p.latin.lowercased().contains(q)
        }
    }

    /// Group plants by `PlantGroup`, sort each section by genus then
    /// common name. Empty groups are omitted.
    public static func sections(for plants: [Plant]) -> [PlantSection] {
        let grouped = Dictionary(grouping: plants, by: PlantGroup.group(for:))
        return PlantGroup.allCases.compactMap { g -> PlantSection? in
            guard let bucket = grouped[g], !bucket.isEmpty else { return nil }
            let sorted = bucket.sorted { lhs, rhs in
                let lg = genus(of: lhs)
                let rg = genus(of: rhs)
                if lg != rg { return lg < rg }
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }
            return PlantSection(group: g, plants: sorted)
        }
    }

    /// First token of the Latin binomial — used as the genus key for
    /// secondary sort.
    public static func genus(of plant: Plant) -> String {
        plant.latin.split(separator: " ").first.map(String.init) ?? plant.latin
    }
}
#endif

import Foundation

// MARK: - BedCapacityModel
//
// The Bed Planting Map's capacity engine. Given a Bed and the resolved
// Plant records for everything currently in `bed.plantCounts`, it answers:
//
//   • How much area is already taken?
//   • How much area is free?
//   • For a given species, how many *more* can still fit?
//   • Are we at capacity for that species?
//
// Footprint per plant uses `π × (spreadCm/2)²`. Species with an unknown
// spread (nil) are treated as "no cap" — the picker won't enforce a max
// for them. Matches the Plant.spreadCm doc comment.

public struct BedCapacityModel {

    public let bed: Bed
    /// Plant records indexed by id. Should contain every plant referenced
    /// in `bed.plantCounts` plus any candidate the UI wants capacity for.
    public let plants: [String: Plant]

    public init(bed: Bed, plants: [String: Plant]) {
        self.bed = bed
        self.plants = plants
    }

    // MARK: - Areas

    public var totalAreaCm2: Double {
        Double(bed.widthCm) * Double(bed.lengthCm)
    }

    public func footprintCm2(plantId: String) -> Double? {
        guard let spread = plants[plantId]?.spreadCm, spread > 0 else { return nil }
        let r = Double(spread) / 2.0
        return .pi * r * r
    }

    public var usedAreaCm2: Double {
        bed.plantCounts.reduce(0.0) { acc, kv in
            let (pid, count) = kv
            return acc + (footprintCm2(plantId: pid) ?? 0) * Double(count)
        }
    }

    public var freeAreaCm2: Double { max(0, totalAreaCm2 - usedAreaCm2) }

    /// Fraction of the bed already occupied (0…1).
    public var fillFraction: Double {
        totalAreaCm2 > 0 ? min(1.0, usedAreaCm2 / totalAreaCm2) : 0
    }

    // MARK: - Per-species capacity

    /// How many additional plants of `plantId` would still fit. Nil means
    /// the species has no known spreadCm, so the cap is not enforced.
    public func maxAdditional(plantId: String) -> Int? {
        guard let fp = footprintCm2(plantId: plantId), fp > 0 else { return nil }
        return max(0, Int(floor(freeAreaCm2 / fp)))
    }

    /// Total current count + how many more would fit. Nil = no cap.
    public func maxAllowed(plantId: String) -> Int? {
        guard let extra = maxAdditional(plantId: plantId) else { return nil }
        let current = bed.plantCounts[plantId] ?? 0
        return current + extra
    }

    /// True if we cannot add any more of this species.
    public func atCapacity(plantId: String) -> Bool {
        (maxAdditional(plantId: plantId) ?? Int.max) == 0
    }
}

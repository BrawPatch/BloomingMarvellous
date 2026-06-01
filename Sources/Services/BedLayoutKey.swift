import Foundation

// MARK: - BedLayoutKey
//
// Builds the canonical "letter key" for a bed's planted species so the
// SwiftUI canvas, the PDF renderer, and the on-screen legend all show
// the same letter next to each plant. Order matches the drawing order:
// tallest at the back first (descending heightCm), name ascending as a
// tiebreaker. Letters wrap A→Z→AA→AZ→BA→… so very dense beds still
// label cleanly.

public struct BedLayoutKeyEntry {
    public let letter: String
    public let plant: Plant
    public let count: Int
    public init(letter: String, plant: Plant, count: Int) {
        self.letter = letter
        self.plant = plant
        self.count = count
    }
}

public enum BedLayoutKey {

    public static func entries(bed: Bed,
                               plants: [String: Plant]) -> [BedLayoutKeyEntry] {
        let pairs: [(Plant, Int)] = bed.plantCounts.compactMap { (pid, count) in
            guard count > 0, let p = plants[pid] else { return nil }
            return (p, count)
        }
        let ordered = pairs.sorted { lhs, rhs in
            let lh = lhs.0.heightCm ?? 0
            let rh = rhs.0.heightCm ?? 0
            if lh != rh { return lh > rh }
            return lhs.0.name < rhs.0.name
        }
        return ordered.enumerated().map { idx, pair in
            BedLayoutKeyEntry(letter: letter(forIndex: idx),
                              plant: pair.0,
                              count: pair.1)
        }
    }

    /// Index 0..25 → "A"…"Z", 26..51 → "AA"…"AZ", and so on.
    public static func letter(forIndex i: Int) -> String {
        if i < 26 {
            return String(UnicodeScalar(UInt8(65 + i)))
        }
        let first  = (i / 26) - 1
        let second =  i % 26
        return String(UnicodeScalar(UInt8(65 + first)))
             + String(UnicodeScalar(UInt8(65 + second)))
    }
}

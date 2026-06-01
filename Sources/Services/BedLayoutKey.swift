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
    /// `#RRGGBB` colour assigned by the layout key (NOT pulled from the
    /// plant's editorial `colorHex`). Picked from a high-contrast palette
    /// indexed by the letter so adjacent species in a dense bed never
    /// look the same, regardless of what the library's editorial tint
    /// happened to be.
    public let paletteHex: String
    public init(letter: String, plant: Plant, count: Int, paletteHex: String) {
        self.letter = letter
        self.plant = plant
        self.count = count
        self.paletteHex = paletteHex
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
                              count: pair.1,
                              paletteHex: palette[idx % palette.count])
        }
    }

    /// 12 visually distinct saturated mid-tones tuned to pop against the
    /// app's mint backgrounds. Order matches `letter(forIndex:)` so the
    /// canvas, the legend, and the PDF all show the same dot for the
    /// same letter. Cycles for more than 12 species — extremely dense
    /// beds will reuse a colour, but the letter is the unique key.
    public static let palette: [String] = [
        "#d34d54", // A — crimson
        "#3680c4", // B — ocean blue
        "#4a8a4d", // C — forest green
        "#d68f3a", // D — amber
        "#8a55a3", // E — purple
        "#3b9c95", // F — teal
        "#d65091", // G — magenta
        "#7a6a2c", // H — olive
        "#264b8a", // I — navy
        "#a44d31", // J — brick
        "#5d8c4a", // K — moss
        "#c46b3a", // L — terracotta
    ]

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

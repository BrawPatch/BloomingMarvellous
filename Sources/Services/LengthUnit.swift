import Foundation

// MARK: - LengthUnit
//
// Display unit for bed dimensions. Model fields stay in cm (`Int`) for
// precision — this enum is only consulted at the binding boundary to
// format values for the UI. AppStorage key `lengthUnit` persists the
// user's choice; the wizard defaults to `.metres`.

public enum LengthUnit: String, CaseIterable, Identifiable, Equatable {
    case metres = "m"
    case feet   = "ft"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .metres: return "Metres (m)"
        case .feet:   return "Feet (ft)"
        }
    }

    public var suffix: String { rawValue }

    /// AppStorage key, used app-wide.
    public static let storageKey = "lengthUnit"
}

// MARK: - LengthFormat
//
// Single source of truth for cm → display-string conversion. Trims
// trailing zeros so "1.50 m" renders as "1.5 m" and "2.00 m" as "2 m".

public enum LengthFormat {
    public static func display(cm: Int, unit: LengthUnit) -> String {
        switch unit {
        case .metres:
            return trimmed(Double(cm) / 100.0) + " m"
        case .feet:
            return trimmed(Double(cm) / 30.48) + " ft"
        }
    }

    /// Combined "W × L" label used by Bed.dimensionLabel(unit:).
    public static func dimensions(widthCm: Int, lengthCm: Int, unit: LengthUnit) -> String {
        switch unit {
        case .metres:
            return "\(trimmed(Double(widthCm) / 100.0)) × \(trimmed(Double(lengthCm) / 100.0)) m"
        case .feet:
            return "\(trimmed(Double(widthCm) / 30.48)) × \(trimmed(Double(lengthCm) / 30.48)) ft"
        }
    }

    private static func trimmed(_ v: Double) -> String {
        var s = String(format: "%.2f", v)
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s
    }
}

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

    /// Plain numeric portion only — used as the placeholder/value of the
    /// manual-entry text field in the bed dimension control. No unit
    /// suffix and no leading sign.
    public static func numericString(cm: Int, unit: LengthUnit) -> String {
        switch unit {
        case .metres: return trimmed(Double(cm) / 100.0)
        case .feet:   return trimmed(Double(cm) / 30.48)
        }
    }

    /// Inverse of `numericString` — accepts whatever the user has typed
    /// (decimal or comma separator, optional trailing whitespace) and
    /// returns the equivalent in cm. Returns nil if the input doesn't
    /// parse to a positive value.
    public static func cmFromString(_ raw: String, unit: LengthUnit) -> Int? {
        let cleaned = raw.replacingOccurrences(of: ",", with: ".")
                         .trimmingCharacters(in: .whitespaces)
        guard let v = Double(cleaned), v >= 0 else { return nil }
        switch unit {
        case .metres: return Int((v * 100.0).rounded())
        case .feet:   return Int((v * 30.48).rounded())
        }
    }

    /// Step (in cm) for the +/- stepper buttons. 0.5 m in metric mode,
    /// 1 ft in imperial mode — chunky enough to feel productive without
    /// blowing past the target size.
    public static func stepCm(for unit: LengthUnit) -> Int {
        switch unit {
        case .metres: return 50
        case .feet:   return 30   // 30 cm ≈ 1 ft, kept as Int for the model
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

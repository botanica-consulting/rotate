import Foundation

/// How placement distances are shown. Defaults to the device's measurement
/// system; the user can pin inches or centimeters in Settings.
enum MeasurementUnit: String, CaseIterable, Identifiable {
    case system
    case inches
    case centimeters

    static let storageKey = "measurementUnit"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "Match device"
        case .inches: "Inches"
        case .centimeters: "Centimeters"
        }
    }

    var usesInches: Bool {
        switch self {
        case .inches: true
        case .centimeters: false
        case .system: Locale.current.measurementSystem == .us
        }
    }

    /// Minimum spacing from the previous site (1 in / 2.5 cm, per Insulet).
    var siteSpacingText: String {
        usesInches ? "1 inch" : "2.5 cm"
    }

    /// Minimum clearance from the navel (2 in / 5 cm, per Insulet).
    var navelClearanceText: String {
        usesInches ? "2 inches" : "5 cm"
    }

    /// The manufacturer's spacing guidance in the user's preferred units —
    /// the one sentence every placement-instruction surface should show.
    var spacingInstruction: String {
        "Place the new Pod at least \(siteSpacingText) from your previous site and \(navelClearanceText) from your navel."
    }
}

import Foundation

/// Placement distances always follow the device's measurement system —
/// inches in the US, centimeters elsewhere. There's no user-facing override
/// (the distances setting was removed), so this has a single case.
enum MeasurementUnit {
    case system

    /// Whether to phrase distances in inches (US) or centimeters.
    var usesInches: Bool { Locale.current.measurementSystem == .us }

    /// Minimum spacing from the previous site (1 in / 2.5 cm, per Insulet).
    var siteSpacingText: String { usesInches ? "1 inch" : "2.5 cm" }

    /// Minimum clearance from the navel (2 in / 5 cm, per Insulet).
    var navelClearanceText: String { usesInches ? "2 inches" : "5 cm" }

    /// The one spacing sentence every placement-instruction surface shows,
    /// worded for the device track.
    func spacingInstruction(for device: DeviceType) -> String {
        switch device {
        case .pump:
            "Place the new pump at least \(siteSpacingText) from your previous site and \(navelClearanceText) from your navel."
        case .cgm:
            "Place the new sensor at least \(siteSpacingText) from your last one, and away from any pump site."
        }
    }
}

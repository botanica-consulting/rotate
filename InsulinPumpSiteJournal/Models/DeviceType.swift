import Foundation

/// The two rotation tracks the app journals independently: the insulin pump
/// ("Pod") and the CGM sensor ("sensor sticker"). Every record carries one,
/// and reads/writes are scoped by it so the two timelines never bleed into
/// each other while still sharing one history list. This is the single place
/// device-specific labels live.
enum DeviceType: String, CaseIterable, Identifiable {
    case pump
    case cgm

    var id: String { rawValue }

    /// Track name for pickers, chips, and section labels.
    var displayName: String {
        switch self {
        case .pump: "Pump"
        case .cgm: "Sensor"
        }
    }

    /// The "add a placement" action title.
    var newActionTitle: String {
        switch self {
        case .pump: "New Pod"
        case .cgm: "New Sensor"
        }
    }

    /// Noun for mid-sentence copy ("open Loop when the Pod is on").
    var noun: String {
        switch self {
        case .pump: "Pod"
        case .cgm: "sensor"
        }
    }

    /// Noun for the start of a sentence or a button.
    var nounCapitalized: String {
        switch self {
        case .pump: "Pod"
        case .cgm: "Sensor"
        }
    }

    /// Example prompts for the free-form notes field, worded per device: a Pod
    /// can leak, a sensor can't — but it can misread or hurt.
    var notesPlaceholder: String {
        switch self {
        case .pump: "Leaked, irritated skin, fell off early…"
        case .cgm: "Bad readings, hurt, irritated skin, fell off early…"
        }
    }
}

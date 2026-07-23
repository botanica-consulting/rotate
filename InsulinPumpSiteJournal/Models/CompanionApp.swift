import Foundation

/// The looping app the flow hands off to after a placement is confirmed.
/// Loop is the only choice today; `none` keeps everything in this app.
///
/// iOS opens other apps by URL scheme, not bundle identifier — Loop builds
/// each carry the builder's own bundle ID, but every standard build
/// registers the same `loop://` scheme (Loop derives it from the app's
/// display name), so the handoff works for all users. Builds renamed for
/// side-by-side installs (e.g. "LoopDev") register a different scheme and
/// won't be detected.
enum CompanionApp: String, CaseIterable, Identifiable {
    case none
    case loop

    /// Companion is chosen per track — a pump and a sensor may hand off to
    /// different apps (or none). Keyed by device so the two settings are
    /// independent.
    static func storageKey(for device: DeviceType) -> String {
        "companionApp-\(device.rawValue)"
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .loop: "Loop"
        }
    }

    /// Scheme URL that brings the companion to the foreground. Loop has no
    /// pod-setup deep link, so this lands on its main screen.
    var launchURL: URL? {
        switch self {
        case .none: nil
        case .loop: URL(string: "loop://")
        }
    }
}

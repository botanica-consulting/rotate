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
    case dexcom

    /// Companion is chosen per track — a pump and a sensor may hand off to
    /// different apps (or none). Keyed by device so the two settings are
    /// independent.
    static func storageKey(for device: DeviceType) -> String {
        "companionApp-\(device.rawValue)"
    }

    /// The companions offered for a given track. Dexcom is a sensor-only
    /// option (you open it to start/warm up a new CGM); the pump track has no
    /// use for it.
    static func options(for device: DeviceType) -> [CompanionApp] {
        switch device {
        case .pump: [.none, .loop]
        case .cgm: [.none, .loop, .dexcom]
        }
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .loop: "Loop"
        case .dexcom: "Dexcom"
        }
    }

    /// Scheme URL that brings the companion to the foreground. Loop has no
    /// pod-setup deep link, so this lands on its main screen.
    ///
    /// NOTE: the Dexcom scheme is unverified — Dexcom publishes no documented
    /// URL scheme, so this is a best guess. If Dexcom registers no scheme the
    /// open silently no-ops (the placement still saves, same as `.none`); once
    /// the real scheme is confirmed on-device, correct it here.
    var launchURL: URL? {
        switch self {
        case .none: nil
        case .loop: URL(string: "loop://")
        case .dexcom: URL(string: "dexcom://")
        }
    }
}

import Foundation

/// The container the app and its widget share.
///
/// The widget can't open the SwiftData store — it lives in the app's own
/// container and is CloudKit-mirrored — so the app writes a small snapshot here
/// instead and the widget reads that.
nonisolated enum AppGroup {
    nonisolated static let id = "group.consulting.botanica.rotate"

    /// The shared defaults, falling back to the app's own if the group is
    /// unavailable (a misconfigured entitlement). The fallback keeps the app
    /// working; only the widget would go stale.
    nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}

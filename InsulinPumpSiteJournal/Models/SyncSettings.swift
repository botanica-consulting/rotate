import Foundation

/// Whether the journal mirrors to the user's private iCloud.
///
/// On by default — sync is what makes the journal survive a lost phone, and
/// most people want it. But placement sites, dates, wear history and free-form
/// notes are personal, health-related records, so leaving the user no way to
/// keep them on one device isn't a defensible default for a health journal.
///
/// The mirror is fixed when the `ModelContainer` is built, so flipping this
/// rebuilds the container (`AppRootView`).
enum SyncSettings {
    static let storageKey = "iCloudSyncEnabled"

    /// The CloudKit container the private mirror writes to.
    static let cloudKitContainerID = "iCloud.consulting.botanica.rotate"

    /// Whether a purge has already removed the mirrored copy. Persisted, so the
    /// result survives a relaunch and Settings doesn't invite a second purge of
    /// a copy that is already gone. Cleared when sync is turned back on, which
    /// uploads the journal again.
    static let copyRemovedKey = "iCloudCopyRemoved"

    /// `defaults` is injectable so the fallback below is testable — it is the
    /// behaviour every 1.1.0 install inherits, so it needs a real test rather
    /// than one that asserts a fresh suite is empty.
    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        // Absent means "never chosen" — which is on, matching the default the
        // toggle shows and the behaviour every 1.1.0 install already has.
        defaults.object(forKey: storageKey) as? Bool ?? true
    }

    static var isEnabled: Bool { isEnabled() }

    static func copyWasRemoved(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: copyRemovedKey)
    }

    static func setCopyWasRemoved(_ removed: Bool, defaults: UserDefaults = .standard) {
        defaults.set(removed, forKey: copyRemovedKey)
    }
}

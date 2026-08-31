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

    static var isEnabled: Bool {
        // Absent means "never chosen" — which is on, matching the default the
        // toggle shows and the behaviour every 1.1.0 install already has.
        UserDefaults.standard.object(forKey: storageKey) as? Bool ?? true
    }
}

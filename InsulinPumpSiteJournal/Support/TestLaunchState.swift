#if DEBUG
import Foundation

/// UI tests launch with `--uitest-reset` for a clean, in-memory store. Anything
/// stored in `UserDefaults` outlives that, so it has to be reset alongside it —
/// otherwise one test turning iCloud sync off (or adding a custom site) changes
/// what the next test sees, and the suite passes or fails by ordering.
enum TestLaunchState {
    static func resetIfRequested() {
        guard CommandLine.arguments.contains("--uitest-reset") else { return }
        UserDefaults.standard.removeObject(forKey: SyncSettings.storageKey)
        // Derived from the store, which is empty on this launch.
        CustomSiteStore.refreshMirror([])
    }
}
#endif

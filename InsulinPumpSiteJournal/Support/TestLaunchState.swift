#if DEBUG
import Foundation

/// UI tests launch with `--uitest-reset` for a clean, in-memory store. Anything
/// stored in `UserDefaults` outlives that, so it has to be reset alongside it —
/// otherwise one test turning iCloud sync off (or adding a custom site) changes
/// what the next test sees, and the suite passes or fails by ordering.
enum TestLaunchState {
    static func resetIfRequested() {
        guard CommandLine.arguments.contains(where: { $0.hasPrefix("--uitest-") }) else { return }
        UserDefaults.standard.removeObject(forKey: SyncSettings.storageKey)
        // A purge result is remembered across launches, so it has to be cleared
        // too — otherwise a hand-tested purge on this simulator leaves Settings
        // showing "Removed" and the sync test can't find the purge button.
        UserDefaults.standard.removeObject(forKey: SyncSettings.copyRemovedKey)
        // A UI test can't answer a Face ID prompt, so the gate must be off and
        // the shared lock must not carry a locked state in from a real launch.
        UserDefaults.standard.removeObject(forKey: AppLockSettings.storageKey)
        AppLock.shared.unlockForTesting()
        // Derived from the store, which is empty on this launch.
        CustomSiteStore.refreshMirror([])
    }
}
#endif

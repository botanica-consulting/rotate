import CloudKit
import Foundation
import SwiftData
import Testing
@testable import InsulinPumpSiteJournal

/// The iCloud sync switch. The mirror is chosen when the container is built, so
/// flipping the switch rebuilds it — and the one thing that must never change
/// with it is which file the journal lives in.
@MainActor
struct SyncSettingsTests {
    /// The highest-risk property of the whole opt-out: `deleteStoreFiles()`
    /// resolves the store URL through the same `storeConfiguration()`, and a
    /// user flipping the switch must not appear to lose their journal. Neither
    /// configuration passes an explicit `url:`, so both have to land on the same
    /// default store file.
    @Test func storeURLIsTheSameWithOrWithoutSync() {
        let synced = ModelConfiguration(cloudKitDatabase: .private(SyncSettings.cloudKitContainerID))
        let local = ModelConfiguration(cloudKitDatabase: .none)
        #expect(synced.url == local.url)
    }

    /// The fallback every 1.1.0 install inherits: no stored preference has to
    /// read as on, or upgrading would silently stop syncing.
    @Test func syncDefaultsToOnWhenNeverChosen() {
        let suite = UserDefaults(suiteName: "sync-settings-tests-\(UUID().uuidString)")!
        defer { suite.removePersistentDomain(forName: suite.description) }

        #expect(SyncSettings.isEnabled(defaults: suite))

        suite.set(false, forKey: SyncSettings.storageKey)
        #expect(!SyncSettings.isEnabled(defaults: suite))

        suite.set(true, forKey: SyncSettings.storageKey)
        #expect(SyncSettings.isEnabled(defaults: suite))

        suite.removeObject(forKey: SyncSettings.storageKey)
        #expect(SyncSettings.isEnabled(defaults: suite))
    }

    /// A finished purge has to survive a relaunch, or Settings offers to remove
    /// a copy that is already gone.
    @Test func aFinishedPurgeIsRemembered() {
        let suite = UserDefaults(suiteName: "purge-flag-tests-\(UUID().uuidString)")!
        defer { suite.removePersistentDomain(forName: suite.description) }

        #expect(!SyncSettings.copyWasRemoved(defaults: suite))
        SyncSettings.setCopyWasRemoved(true, defaults: suite)
        #expect(SyncSettings.copyWasRemoved(defaults: suite))
        // Turning sync back on uploads the journal again, so it stops being true.
        SyncSettings.setCopyWasRemoved(false, defaults: suite)
        #expect(!SyncSettings.copyWasRemoved(defaults: suite))
    }

    /// A local-only container still opens and works — no iCloud account, no
    /// entitlement, no mirror.
    @Test func localOnlyContainerOpensAndStores() throws {
        let storeURL = URL.temporaryDirectory
            .appending(path: "sync-off-test-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let container = try ModelContainer(
            for: PlacementRecord.self, CustomSite.self,
            configurations: ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)
        try JournalStore(context: context).startPlacement(siteID: "abdomen-left")
        #expect(try context.fetch(FetchDescriptor<PlacementRecord>()).count == 1)
    }

    @Test func purgeTargetsCoreDataMirrorZone() {
        // Not an app choice — Core Data fixes the zone name, and deleting that
        // zone is what removes the mirrored copy.
        #expect(CloudKitPurge.zoneName == "com.apple.coredata.cloudkit.zone")
    }

    /// "Already gone" has to count as success, or a second purge — or a purge on
    /// an account that never synced — reports a failure the user can't act on.
    /// The partial-failure case is the one worth pinning down: CloudKit reports
    /// zone deletions through `partialErrorsByItemID` rather than the top-level
    /// error.
    @Test func aMissingZoneCountsAsAlreadyRemoved() {
        let zoneID = CKRecordZone.ID(zoneName: CloudKitPurge.zoneName, ownerName: CKCurrentUserDefaultName)

        #expect(CloudKitPurge.isAlreadyGone(CKError(.zoneNotFound)))
        #expect(CloudKitPurge.isAlreadyGone(CKError(.unknownItem)))

        let partial = CKError(.partialFailure, userInfo: [
            CKPartialErrorsByItemIDKey: [zoneID: CKError(.zoneNotFound)]
        ])
        #expect(CloudKitPurge.isAlreadyGone(partial))
    }

    /// The other half: a real failure must not be swallowed as success, or the
    /// UI would claim the copy was removed when it is still there.
    @Test func realFailuresAreNotTreatedAsRemoved() {
        let zoneID = CKRecordZone.ID(zoneName: CloudKitPurge.zoneName, ownerName: CKCurrentUserDefaultName)

        #expect(!CloudKitPurge.isAlreadyGone(CKError(.networkUnavailable)))
        #expect(!CloudKitPurge.isAlreadyGone(CKError(.notAuthenticated)))
        #expect(!CloudKitPurge.isAlreadyGone(CKError(.permissionFailure)))

        // A partial failure that isn't only about a missing zone.
        let mixed = CKError(.partialFailure, userInfo: [
            CKPartialErrorsByItemIDKey: [zoneID: CKError(.networkUnavailable)]
        ])
        #expect(!CloudKitPurge.isAlreadyGone(mixed))

        // A partial failure with nothing in it isn't evidence of anything.
        let empty = CKError(.partialFailure, userInfo: [
            CKPartialErrorsByItemIDKey: [CKRecordZone.ID: CKError]()
        ])
        #expect(!CloudKitPurge.isAlreadyGone(empty))

        // Not a CKError at all.
        #expect(!CloudKitPurge.isAlreadyGone(CocoaError(.fileNoSuchFile)))
    }
}

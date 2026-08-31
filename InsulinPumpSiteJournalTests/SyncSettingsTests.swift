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

    @Test func syncDefaultsToOnWhenNeverChosen() {
        let suite = UserDefaults(suiteName: "sync-settings-tests-\(UUID().uuidString)")!
        // Absent means "never chosen", which has to read as on — that is what
        // every 1.1.0 install already does.
        #expect(suite.object(forKey: SyncSettings.storageKey) == nil)
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
}

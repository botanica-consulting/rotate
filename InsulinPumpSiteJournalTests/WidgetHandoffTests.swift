import Foundation
import SwiftData
import Testing
@testable import InsulinPumpSiteJournal

/// What the app hands the widget, and what it does with a tap coming back.
/// `AppRouter` is a singleton, so this suite runs serially.
@MainActor
@Suite(.serialized)
struct WidgetHandoffTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "widget-handoff-tests-\(UUID().uuidString)")!
    }

    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: PlacementRecord.self, CustomSite.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: Publishing

    @Test func publishesTheCurrentPlacementOnBothTracks() throws {
        let store = defaults()
        let context = try context()
        let journal = JournalStore(context: context)
        try journal.startPlacement(siteID: "abdomen-left", deviceType: .pump)
        try journal.startPlacement(siteID: "back-upper-arm-left", deviceType: .cgm)

        SnapshotPublisher.refresh(from: try journal.history(), to: store)

        let snapshot = SiteSnapshot.load(from: store)
        #expect(snapshot.pump?.siteTitle == "Left abdomen")
        #expect(snapshot.cgm?.siteTitle == "Left upper arm")
    }

    @Test func onlyTheNewestPlacementIsPublished() throws {
        let store = defaults()
        let context = try context()
        let journal = JournalStore(context: context)
        try journal.startPlacement(siteID: "abdomen-left", deviceType: .pump)
        try journal.startPlacement(siteID: "front-thigh-left", deviceType: .pump)

        SnapshotPublisher.refresh(from: try journal.history(), to: store)
        #expect(SiteSnapshot.load(from: store).pump?.siteTitle == "Left front thigh")
    }

    @Test func aTrackWithNothingOnPublishesNothing() throws {
        let store = defaults()
        let context = try context()
        let journal = JournalStore(context: context)
        let record = try journal.startPlacement(siteID: "abdomen-left", deviceType: .pump)
        SnapshotPublisher.refresh(from: try journal.history(), to: store)
        #expect(SiteSnapshot.load(from: store).pump != nil)

        // Deleting the only placement must clear the widget, not leave it stale.
        try journal.delete(record)
        SnapshotPublisher.refresh(from: try journal.history(), to: store)
        #expect(SiteSnapshot.load(from: store).pump == nil)
        #expect(SiteSnapshot.load(from: store).cgm == nil)
    }

    @Test func anEditedStartTimeReachesTheWidget() throws {
        let store = defaults()
        let context = try context()
        let journal = JournalStore(context: context)
        let record = try journal.startPlacement(siteID: "abdomen-left", deviceType: .pump)
        SnapshotPublisher.refresh(from: try journal.history(), to: store)

        let moved = record.placedAt.addingTimeInterval(-4 * 3600)
        try journal.updateTiming(record, placedAt: moved, removedAt: nil)
        SnapshotPublisher.refresh(from: try journal.history(), to: store)

        #expect(SiteSnapshot.load(from: store).pump?.placedAt == moved)
    }

    @Test func aCustomSiteReachesTheWidgetByName() throws {
        let store = defaults()
        let mirror = defaults()
        let context = try context()
        let journal = JournalStore(context: context)
        let calf = try journal.addCustomSite(name: "Left calf", for: .pump)
        CustomSiteStore.refreshMirror(try journal.customSites(includingArchived: true), defaults: mirror)
        try journal.startPlacement(siteID: calf.siteID, deviceType: .pump)

        // The widget must never be handed a raw "custom-<uuid>": the name is
        // resolved app-side, before publishing. Resolution is injected here
        // against an isolated mirror rather than the app-wide one, which other
        // suites read concurrently.
        SnapshotPublisher.refresh(
            from: try journal.history(),
            to: store,
            resolveTitle: { CustomSiteStore.site(for: $0, defaults: mirror)?.title ?? $0 }
        )

        #expect(SiteSnapshot.load(from: store).pump?.siteTitle == "Left calf")
    }

    // MARK: The tap coming back

    @Test func theWidgetsOwnURLIsAcceptedByTheApp() throws {
        let router = AppRouter.shared
        // The exact URL the widget composes has to be the one the app resolves —
        // they are built in different processes and only meet at runtime.
        for device in DeviceType.allCases {
            router.pendingNewDevice = nil
            let url = try #require(DeepLink.newPlacement(for: device))
            #expect(router.handle(url))
            #expect(router.pendingNewDevice == device)
        }
        router.pendingNewDevice = nil
    }

    @Test func foreignURLsLeaveTheRouterAlone() throws {
        let router = AppRouter.shared
        router.pendingNewDevice = nil
        #expect(!router.handle(try #require(URL(string: "loop://"))))
        #expect(router.pendingNewDevice == nil)
    }

    /// The router must not act on a link naming a track it can't resolve.
    @Test func aRouterIgnoresAnUnknownTrack() throws {
        let router = AppRouter.shared
        router.pendingNewDevice = nil
        #expect(!router.handle(try #require(URL(string: "rotate://new?device=banana"))))
        #expect(router.pendingNewDevice == nil)
    }

    @Test func siriRequestSurvivesUntilConsumed() {
        // A cold launch from Siri sets this before any view exists, so it has to
        // still be there when the journal appears.
        let router = AppRouter.shared
        router.pendingNewDevice = nil
        router.requestNewPlacement(for: .cgm)
        #expect(router.pendingNewDevice == .cgm)
        router.pendingNewDevice = nil
        #expect(router.pendingNewDevice == nil)
    }
}

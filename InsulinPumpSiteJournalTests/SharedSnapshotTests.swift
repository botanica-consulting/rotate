import Foundation
import Testing
@testable import InsulinPumpSiteJournal

/// The app↔widget contract: the snapshot in shared defaults, the wear
/// arithmetic both sides use, and the deep link the widget composes.
struct SharedSnapshotTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "shared-snapshot-tests-\(UUID().uuidString)")!
    }

    // MARK: Snapshot

    @Test func snapshotRoundTrips() {
        let store = defaults()
        let placedAt = Date(timeIntervalSince1970: 1_750_000_000)
        var snapshot = SiteSnapshot()
        snapshot.setTrack(SiteSnapshot.Track(placedAt: placedAt, siteTitle: "Left abdomen"), for: .pump)
        SiteSnapshot.save(snapshot, to: store)

        let loaded = SiteSnapshot.load(from: store)
        #expect(loaded == snapshot)
        #expect(loaded.track(for: .pump)?.siteTitle == "Left abdomen")
        #expect(loaded.track(for: .cgm) == nil)
    }

    @Test func missingSnapshotLoadsEmptyRatherThanFailing() {
        // A widget added before the app has ever run must render, not crash.
        let loaded = SiteSnapshot.load(from: defaults())
        #expect(loaded.pump == nil)
        #expect(loaded.cgm == nil)
    }

    @Test func corruptSnapshotLoadsEmpty() {
        let store = defaults()
        store.set(Data("not json".utf8), forKey: SiteSnapshot.storageKey)
        #expect(SiteSnapshot.load(from: store) == SiteSnapshot())
    }

    @Test func tracksAreIndependent() {
        var snapshot = SiteSnapshot()
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        snapshot.setTrack(SiteSnapshot.Track(placedAt: now, siteTitle: "Left arm"), for: .cgm)
        #expect(snapshot.pump == nil)
        #expect(snapshot.cgm?.siteTitle == "Left arm")
        snapshot.setTrack(nil, for: .cgm)
        #expect(snapshot.cgm == nil)
    }

    // MARK: Wear arithmetic

    @Test func hoursMatchWhatTheAppShows() {
        let placedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let now = placedAt.addingTimeInterval(27.9 * 3600)
        // Truncated, not rounded — and the app's counter must agree exactly, or
        // the widget and the card would differ by an hour.
        #expect(WearDuration.hours(at: now, since: placedAt) == 27)
        #expect(WearDuration.text(at: now, since: placedAt) == "27h")
        #expect(PodAgeCounter.text(at: now, since: placedAt) == "27h")
    }

    @Test func negativeElapsedFloorsAtZero() {
        let placedAt = Date(timeIntervalSince1970: 1_750_000_000)
        #expect(WearDuration.hours(at: placedAt.addingTimeInterval(-3_600), since: placedAt) == 0)
    }

    @Test func spokenTextIsSingularAtOneHour() {
        let placedAt = Date(timeIntervalSince1970: 1_750_000_000)
        #expect(WearDuration.spokenText(at: placedAt.addingTimeInterval(3_600), since: placedAt) == "1 hour")
        #expect(WearDuration.spokenText(at: placedAt.addingTimeInterval(7_200), since: placedAt) == "2 hours")
    }

    @Test func nextHourBoundaryIsWhenTheCountTicksOver() {
        let placedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let now = placedAt.addingTimeInterval(2.5 * 3600)
        let next = WearDuration.nextHourBoundary(after: now, since: placedAt)

        #expect(next == placedAt.addingTimeInterval(3 * 3600))
        // The whole point: the displayed number must differ across that instant.
        #expect(WearDuration.hours(at: now, since: placedAt) == 2)
        #expect(WearDuration.hours(at: next, since: placedAt) == 3)
    }

    @Test func nextHourBoundaryFromExactlyOnTheHourAdvances() {
        let placedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let onTheHour = placedAt.addingTimeInterval(3 * 3600)
        // Must move forward, or the timeline would emit duplicate dates.
        #expect(WearDuration.nextHourBoundary(after: onTheHour, since: placedAt) > onTheHour)
    }

    // MARK: Deep link

    @Test func deepLinkRoundTripsPerTrack() throws {
        for device in DeviceType.allCases {
            let url = try #require(DeepLink.newPlacement(for: device))
            #expect(DeepLink.newPlacementDevice(from: url) == device)
        }
    }

    @Test func foreignURLsAreIgnored() throws {
        // The handoff target's scheme must never be mistaken for ours.
        #expect(DeepLink.newPlacementDevice(from: try #require(URL(string: "loop://"))) == nil)
        #expect(DeepLink.newPlacementDevice(from: try #require(URL(string: "https://example.com/new"))) == nil)
        #expect(DeepLink.newPlacementDevice(from: try #require(URL(string: "rotate://settings"))) == nil)
    }

    @Test func linkWithoutAKnownTrackFallsBackToPump() throws {
        #expect(DeepLink.newPlacementDevice(from: try #require(URL(string: "rotate://new"))) == .pump)
        #expect(DeepLink.newPlacementDevice(from: try #require(URL(string: "rotate://new?device=banana"))) == .pump)
    }
}

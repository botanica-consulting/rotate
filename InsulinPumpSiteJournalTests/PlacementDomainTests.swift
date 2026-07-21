import Foundation
import SwiftData
import Testing
@testable import InsulinPumpSiteJournal

@MainActor
struct SiteIDTests {
    @Test func legacyQuadrantIDsCanonicalize() {
        #expect(SiteID.canonical("abdomen-upper-left") == "abdomen-left")
        #expect(SiteID.canonical("thigh-right") == "front-thigh-right")
        #expect(SiteID.canonical("arm-upper-left") == "back-upper-arm-left")
        #expect(SiteID.canonical("buttock-upper-right") == "upper-buttock-right")
    }

    @Test func currentIDsPassThrough() {
        for site in PumpSite.catalog {
            #expect(SiteID.canonical(site.id) == site.id)
        }
    }

    @Test func legacyRecordCountsTowardRecency() {
        // A placement stored under the old ID must age the canonical site.
        let history = [PlacementRecord(siteID: "abdomen-upper-left", placedAt: .now)]
        let recency = SiteRecencyModel(history: history)
        #expect(recency.tier(for: "abdomen-left") == .veryRecent)
        #expect(recency.veryRecentSiteIDs.contains("abdomen-left"))
    }

    @Test func legacyRecordExcludesSiteFromSuggestions() {
        // The immediately previous site must stay excluded even when its
        // record uses the legacy spelling.
        let history = [PlacementRecord(siteID: "abdomen-upper-left", placedAt: .now)]
        let suggestions = SiteSuggestionEngine().suggestions(
            from: PumpSite.catalog,
            history: history
        )
        #expect(!suggestions.map(\.id).contains("abdomen-left"))
    }
}

@MainActor
struct PlacementTimelineTests {
    private func record(
        _ siteID: String,
        daysAgo: Double,
        removedAt: Date? = nil
    ) -> PlacementRecord {
        PlacementRecord(
            siteID: siteID,
            placedAt: Date(timeIntervalSinceNow: -daysAgo * 86_400),
            removedAt: removedAt
        )
    }

    @Test func newestOpenRecordIsCurrent() {
        let timeline = PlacementTimeline(records: [
            record("abdomen-left", daysAgo: 1),
            record("abdomen-right", daysAgo: 4, removedAt: Date(timeIntervalSinceNow: -3.5 * 86_400)),
        ])
        #expect(timeline.current?.siteID == "abdomen-left")
        #expect(timeline.current?.stop == nil)
    }

    @Test func closedNewestRecordMeansNoCurrentPod() {
        let stop = Date(timeIntervalSinceNow: -0.5 * 86_400)
        let timeline = PlacementTimeline(records: [
            record("abdomen-left", daysAgo: 1, removedAt: stop)
        ])
        #expect(timeline.current == nil)
        #expect(timeline.entries.first?.stop == stop)
    }

    @Test func missingStopsAreInferredFromNextPlacement() {
        // Pre-stop-tracking records: nil removedAt on an older record resolves
        // to the next placement's start.
        let timeline = PlacementTimeline(records: [
            record("abdomen-left", daysAgo: 1),
            record("abdomen-right", daysAgo: 4),
        ])
        let older = timeline.entries[1]
        #expect(older.stop == timeline.entries[0].placedAt)
    }

    @Test func stopsNeverPrecedeStarts() {
        let placed = Date(timeIntervalSinceNow: -86_400)
        let corrupt = PlacementRecord(
            siteID: "abdomen-left",
            placedAt: placed,
            removedAt: placed.addingTimeInterval(-3_600)
        )
        let timeline = PlacementTimeline(records: [corrupt])
        #expect(timeline.entries[0].stop == placed)
        #expect(timeline.entries[0].wear == 0)
    }

    @Test func averageWearUsesResolvedStops() throws {
        let timeline = PlacementTimeline(records: [
            record("abdomen-left", daysAgo: 0),                       // open — excluded
            record("abdomen-right", daysAgo: 2,
                   removedAt: Date(timeIntervalSinceNow: -86_400)),   // 24h stamped
            record("front-thigh-left", daysAgo: 4),                   // inferred: 2 days
        ])
        let average = try #require(timeline.averageWear)
        #expect(abs(average - 1.5 * 86_400) < 1)
    }

    @Test func lastUsedGroupsByCanonicalID() {
        let timeline = PlacementTimeline(records: [
            record("abdomen-upper-left", daysAgo: 3)
        ])
        #expect(timeline.lastUsedBySite["abdomen-left"] != nil)
        #expect(timeline.lastUsedBySite["abdomen-upper-left"] == nil)
    }

    @Test func tiedTimestampsAreDeterministic() {
        let when = Date.now
        let a = PlacementRecord(siteID: "abdomen-left", placedAt: when)
        let b = PlacementRecord(siteID: "abdomen-right", placedAt: when)
        let one = PlacementTimeline(records: [a, b]).entries.map(\.id)
        let two = PlacementTimeline(records: [b, a]).entries.map(\.id)
        #expect(one == two)
    }
}

@MainActor
struct JournalStoreTests {
    private func makeStore() throws -> JournalStore {
        let container = try ModelContainer(
            for: PlacementRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return JournalStore(context: ModelContext(container))
    }

    @Test func startPlacementClosesEveryOpenRecord() throws {
        let store = try makeStore()
        // Two open records (an anomaly the store must repair on write).
        store.context.insert(PlacementRecord(siteID: "abdomen-left", placedAt: .now.addingTimeInterval(-7 * 86_400)))
        store.context.insert(PlacementRecord(siteID: "abdomen-right", placedAt: .now.addingTimeInterval(-3 * 86_400)))
        try store.save()

        let started = try store.startPlacement(siteID: "front-thigh-left")

        let all = try store.history()
        #expect(all.count == 3)
        let open = all.filter { $0.removedAt == nil }
        #expect(open.map(\.id) == [started.id])
        for closed in all where closed.id != started.id {
            let removedAt = try #require(closed.removedAt)
            #expect(removedAt >= closed.placedAt)
        }
    }

    @Test func startPlacementNeverBackdatesARemoval() throws {
        let store = try makeStore()
        // An open record whose start is in the future (clock change): closing
        // it must not produce removedAt < placedAt.
        let futureStart = Date.now.addingTimeInterval(3_600)
        store.context.insert(PlacementRecord(siteID: "abdomen-left", placedAt: futureStart))
        try store.save()

        try store.startPlacement(siteID: "abdomen-right")

        let closed = try #require(try store.history().first { $0.siteID == "abdomen-left" })
        let removedAt = try #require(closed.removedAt)
        #expect(removedAt >= futureStart)
    }

    @Test func deletingTheCurrentRecordNeverReopensThePrevious() throws {
        let store = try makeStore()
        try store.startPlacement(siteID: "abdomen-left", at: .now.addingTimeInterval(-3 * 86_400))
        let current = try store.startPlacement(siteID: "abdomen-right")

        try store.delete(current)

        let remaining = try store.history()
        #expect(remaining.count == 1)
        #expect(remaining[0].removedAt != nil)
        #expect(PlacementTimeline(records: remaining).current == nil)
    }

    @Test func resetEmptiesTheJournal() throws {
        let store = try makeStore()
        try store.startPlacement(siteID: "abdomen-left")
        try store.startPlacement(siteID: "abdomen-right")

        try store.reset()

        #expect(try store.history().isEmpty)
    }
}

@MainActor
struct PodAgeTests {
    @Test func hourBoundaries() {
        let start = Date.now
        #expect(PodAgeCounter.text(at: start.addingTimeInterval(59 * 60), since: start) == "0h")
        #expect(PodAgeCounter.text(at: start.addingTimeInterval(60 * 60), since: start) == "1h")
        #expect(PodAgeCounter.text(at: start.addingTimeInterval(26.5 * 3_600), since: start) == "26h")
        // A clock rolled backward must not show negative hours.
        #expect(PodAgeCounter.text(at: start.addingTimeInterval(-3_600), since: start) == "0h")
        #expect(PodAgeCounter.spokenText(at: start.addingTimeInterval(2 * 3_600), since: start) == "2 hours")
    }
}

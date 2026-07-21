import Foundation
import Testing
@testable import InsulinPumpSiteJournal

struct SiteSuggestionEngineTests {
    private let engine = SiteSuggestionEngine()
    private let catalog = PumpSite.catalog

    private func record(_ siteID: String, daysAgo: Double) -> PlacementRecord {
        PlacementRecord(
            siteID: siteID,
            placedAt: Date.now.addingTimeInterval(-daysAgo * 86_400)
        )
    }

    @Test func emptyHistoryReturnsFourDistinctStarters() {
        let result = engine.suggestions(from: catalog, history: [])

        #expect(result.count == 4)
        #expect(Set(result.map(\.id)).count == 4)
        #expect(Set(result.map(\.region)).count == 4)
        #expect(result.map(\.id) == PumpSite.starterSiteIDs)
    }

    @Test func excludesImmediatelyPreviousSite() {
        let history = [
            record("thigh-left", daysAgo: 0),
            record("abdomen-upper-left", daysAgo: 3),
        ]

        let result = engine.suggestions(from: catalog, history: history)

        #expect(!result.map(\.id).contains("thigh-left"))
        #expect(result.count == 4)
    }

    @Test func neverUsedSitesPrecedeUsedSites() {
        let history = [
            record("abdomen-upper-left", daysAgo: 1),
            record("thigh-left", daysAgo: 5),
            record("arm-upper-left", daysAgo: 9),
        ]
        let usedIDs = Set(history.map(\.siteID))

        let result = engine.suggestions(from: catalog, history: history)

        // Nine sites were never used, spanning all regions — every suggestion
        // should come from them.
        #expect(result.allSatisfy { !usedIDs.contains($0.id) })
    }

    @Test func prefersLeastRecentlyUsedSites() {
        // Every site used once; catalog index i placed (i + 1) days ago, so
        // the last catalog entry is the least recently used and catalog[0]
        // (1 day ago) is the excluded previous site.
        let history = catalog.enumerated().map { index, site in
            record(site.id, daysAgo: Double(index + 1))
        }

        let result = engine.suggestions(from: catalog, history: history)

        // Oldest-first with region diversity: one site per region, walking
        // from the least recently used end of the catalog.
        #expect(result.map(\.id) == [
            "buttock-upper-right",
            "lower-back-right",
            "arm-upper-right",
            "thigh-right",
        ])
    }

    @Test func suggestionsAreRegionDiverseWherePossible() {
        // Naive LRU would return the four abdomen sites: they are by far the
        // oldest. Region diversity must spread the result instead.
        var history = [
            record("abdomen-upper-left", daysAgo: 100),
            record("abdomen-upper-right", daysAgo: 99),
            record("abdomen-lower-left", daysAgo: 98),
            record("abdomen-lower-right", daysAgo: 97),
        ]
        let nonAbdomen = catalog.filter { $0.region != .abdomen }
        history += nonAbdomen.enumerated().map { index, site in
            record(site.id, daysAgo: Double(index + 1))
        }

        let result = engine.suggestions(from: catalog, history: history)

        #expect(result.count == 4)
        #expect(Set(result.map(\.region)).count == 4)
        #expect(result.contains { $0.region == .abdomen })
    }

    @Test func outputIsDeterministic() {
        let history = [
            record("abdomen-upper-left", daysAgo: 2),
            record("thigh-right", daysAgo: 7),
            record("arm-upper-left", daysAgo: 12),
        ]

        let first = engine.suggestions(from: catalog, history: history)
        let second = engine.suggestions(from: catalog, history: history)

        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test func resultContainsNoDuplicates() {
        // The same site placed repeatedly must not produce duplicates.
        let history = [
            record("abdomen-upper-left", daysAgo: 1),
            record("abdomen-upper-left", daysAgo: 10),
            record("abdomen-upper-left", daysAgo: 20),
            record("thigh-left", daysAgo: 4),
            record("thigh-left", daysAgo: 15),
        ]

        let result = engine.suggestions(from: catalog, history: history)

        #expect(Set(result.map(\.id)).count == result.count)
        #expect(result.count == 4)
    }
}

import Foundation
import Testing
@testable import InsulinPumpSiteJournal

struct SiteRecencyModelTests {
    private func record(_ siteID: String, daysAgo: Double) -> PlacementRecord {
        PlacementRecord(
            siteID: siteID,
            placedAt: Date.now.addingTimeInterval(-daysAgo * 86_400)
        )
    }

    @Test func tiersFollowRecencyRanks() {
        // Catalog order used 1...12 days ago: index 0 most recent.
        let history = PumpSite.catalog.enumerated().map { index, site in
            record(site.id, daysAgo: Double(index + 1))
        }
        let model = SiteRecencyModel(history: history)

        #expect(model.tier(for: PumpSite.catalog[0].id) == .veryRecent)
        #expect(model.tier(for: PumpSite.catalog[2].id) == .veryRecent)
        #expect(model.tier(for: PumpSite.catalog[3].id) == .recent)
        #expect(model.tier(for: PumpSite.catalog[5].id) == .recent)
        #expect(model.tier(for: PumpSite.catalog[6].id) == .relativelyRecent)
        #expect(model.tier(for: PumpSite.catalog[8].id) == .relativelyRecent)
        #expect(model.tier(for: PumpSite.catalog[9].id) == .base)
        #expect(model.tier(for: PumpSite.catalog[11].id) == .base)
    }

    @Test func neverUsedSitesAreBaseTier() {
        let model = SiteRecencyModel(history: [record("front-thigh-left", daysAgo: 1)])
        #expect(model.tier(for: "front-thigh-left") == .veryRecent)
        #expect(model.tier(for: "back-upper-arm-left") == .base)
    }

    @Test func veryRecentSetContainsAtMostLastThreeUsedSites() {
        let history = [
            record("front-thigh-left", daysAgo: 1),
            record("back-upper-arm-left", daysAgo: 2),
            record("abdomen-left", daysAgo: 3),
            record("lower-back-left", daysAgo: 4),
        ]
        let model = SiteRecencyModel(history: history)
        #expect(model.veryRecentSiteIDs == ["front-thigh-left", "back-upper-arm-left", "abdomen-left"])

        let sparse = SiteRecencyModel(history: [record("front-thigh-left", daysAgo: 1)])
        #expect(sparse.veryRecentSiteIDs == ["front-thigh-left"])
    }

    @Test func repeatedPlacementsUseLatestDate() {
        let history = [
            record("front-thigh-left", daysAgo: 40),
            record("front-thigh-left", daysAgo: 1),
            record("back-upper-arm-left", daysAgo: 2),
        ]
        let model = SiteRecencyModel(history: history)
        #expect(model.veryRecentSiteIDs.contains("front-thigh-left"))
    }
}

import Foundation
import SwiftData
import Testing
@testable import InsulinPumpSiteJournal

/// The CGM sensor vertical: a second rotation track that shares the record
/// store and site geometry with the pump track but is journaled independently.
struct DeviceTrackTests {
    @Test func cgmCatalogIsTheSixSensorSites() {
        let ids = PumpSite.sites(for: .cgm).map(\.id)
        #expect(ids == [
            "back-upper-arm-left",
            "back-upper-arm-right",
            "abdomen-left",
            "abdomen-right",
            "upper-buttock-left",
            "upper-buttock-right",
        ])
        // Sensor sites are a subset of the pump catalog and reuse its baked
        // area geometry for every body type — no new artwork.
        for site in PumpSite.sites(for: .cgm) {
            #expect(PumpSite.site(for: site.id) != nil)
            for bodyType in BodyType.allCases {
                #expect(
                    SiteAreaCatalog.area(for: site.id, bodyType: bodyType) != nil,
                    "missing \(bodyType.rawValue) area for sensor site \(site.id)"
                )
            }
        }
    }

    @Test func cgmSitesSpanThreeSensorRegions() {
        let regions = Set(PumpSite.sites(for: .cgm).map(\.region))
        #expect(regions == [.arm, .abdomen, .upperButtock])
    }

    @Test func perDeviceTimelinesHaveIndependentCurrent() {
        let records = [
            PlacementRecord(siteID: "abdomen-left", placedAt: .now, deviceType: DeviceType.pump.rawValue),
            PlacementRecord(
                siteID: "back-upper-arm-left",
                placedAt: .now.addingTimeInterval(-3_600),
                deviceType: DeviceType.cgm.rawValue
            ),
        ]

        #expect(PlacementTimeline(records: records, deviceType: .pump).current?.siteID == "abdomen-left")
        #expect(PlacementTimeline(records: records, deviceType: .cgm).current?.siteID == "back-upper-arm-left")
        // The unified list still sees both tracks.
        #expect(PlacementTimeline(records: records).entries.count == 2)
    }

    @Test func entryReportsItsDeviceTrack() {
        let records = [
            PlacementRecord(siteID: "abdomen-left", placedAt: .now, deviceType: DeviceType.cgm.rawValue),
        ]
        #expect(PlacementTimeline(records: records).entries.first?.deviceType == .cgm)
    }

    @Test func cgmSuggestionsNeverLeaveTheSensorCatalog() {
        let engine = SiteSuggestionEngine()
        let sensorIDs = Set(PumpSite.cgmSiteIDs)

        // Empty history → the sensor starters, in order.
        let starters = engine.suggestions(
            from: PumpSite.sites(for: .cgm),
            history: [],
            starterSiteIDs: PumpSite.starterSiteIDs(for: .cgm)
        )
        #expect(starters.map(\.id) == PumpSite.cgmStarterSiteIDs)

        // With history, results stay within the sensor sites and exclude the
        // immediately previous one.
        let history = [
            PlacementRecord(siteID: "abdomen-left", placedAt: .now, deviceType: DeviceType.cgm.rawValue),
        ]
        let result = engine.suggestions(
            from: PumpSite.sites(for: .cgm),
            history: history,
            starterSiteIDs: PumpSite.starterSiteIDs(for: .cgm)
        )
        #expect(result.allSatisfy { sensorIDs.contains($0.id) })
        #expect(!result.map(\.id).contains("abdomen-left"))
    }
}

@MainActor
struct DeviceTrackStoreTests {
    private func makeStore() throws -> JournalStore {
        let container = try ModelContainer(
            for: PlacementRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return JournalStore(context: ModelContext(container))
    }

    @Test func startingASensorDoesNotCloseAnOpenPump() throws {
        let store = try makeStore()
        let pump = try store.startPlacement(siteID: "abdomen-left", deviceType: .pump)
        let sensor = try store.startPlacement(siteID: "back-upper-arm-left", deviceType: .cgm)

        let all = try store.history()
        #expect(all.count == 2)
        // Both tracks keep their own open placement.
        #expect(all.first { $0.id == pump.id }?.removedAt == nil)
        #expect(all.first { $0.id == sensor.id }?.removedAt == nil)
    }

    @Test func startPlacementClosesOnlyTheSameDeviceTrack() throws {
        let store = try makeStore()
        let pump = try store.startPlacement(siteID: "abdomen-left", deviceType: .pump)
        let sensor = try store.startPlacement(siteID: "back-upper-arm-left", deviceType: .cgm)

        // Replacing the pump must close the old pump but leave the sensor on.
        let pump2 = try store.startPlacement(siteID: "abdomen-right", deviceType: .pump)

        let after = try store.history()
        #expect(after.first { $0.id == pump.id }?.removedAt != nil)
        #expect(after.first { $0.id == sensor.id }?.removedAt == nil)
        #expect(after.first { $0.id == pump2.id }?.removedAt == nil)

        // One open per track.
        #expect(PlacementTimeline(records: after, deviceType: .pump).current?.id == pump2.id)
        #expect(PlacementTimeline(records: after, deviceType: .cgm).current?.id == sensor.id)
    }

    @Test func recordsDefaultToThePumpTrack() throws {
        // A record written without a device (e.g. migrated legacy data) reads
        // back as a pump placement.
        let store = try makeStore()
        store.context.insert(PlacementRecord(siteID: "abdomen-left"))
        try store.save()

        let record = try #require(try store.history().first)
        #expect(record.deviceType == DeviceType.pump.rawValue)
    }
}

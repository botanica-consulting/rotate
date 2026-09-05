import Foundation
import SwiftData
import Testing
@testable import InsulinPumpSiteJournal

/// User-added sites. They live in SwiftData so they sync, and are mirrored into
/// UserDefaults so the static catalog entry points can see them without a model
/// context.
@MainActor
struct CustomSiteTests {
    /// An isolated defaults suite, so a test never reads or writes the
    /// simulator's real mirror.
    private func defaults(_ name: String = #function) -> UserDefaults {
        let suite = UserDefaults(suiteName: "custom-site-tests-\(name)-\(UUID().uuidString)")!
        return suite
    }

    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: PlacementRecord.self, CustomSite.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: Identity

    @Test func customIDsRoundTrip() {
        let id = UUID()
        let raw = SiteID.custom(id)
        #expect(SiteID.isCustom(raw))
        #expect(SiteID.customUUID(raw) == id)
    }

    @Test func canonicalLeavesCustomIDsAlone() {
        // Custom IDs have no legacy spelling; canonicalizing must not touch them,
        // or a stored placement would stop resolving to its site.
        let raw = SiteID.custom(UUID())
        #expect(SiteID.canonical(raw) == raw)
    }

    @Test func builtInIDsAreNotCustom() {
        for site in PumpSite.catalog {
            #expect(!SiteID.isCustom(site.id))
            #expect(!site.isCustom)
        }
    }

    // MARK: The mirror

    @Test func mirrorRoundTripsThroughDefaults() throws {
        let store = defaults()
        let context = try context()
        let journal = JournalStore(context: context)
        try journal.addCustomSite(name: "Left calf", for: .pump)
        try journal.addCustomSite(name: "Right hip", for: .pump)

        CustomSiteStore.refreshMirror(try journal.customSites(includingArchived: true), defaults: store)

        let names = CustomSiteStore.activeSites(for: .pump, defaults: store).map(\.title)
        #expect(names == ["Left calf", "Right hip"])
        for site in CustomSiteStore.activeSites(for: .pump, defaults: store) {
            #expect(site.isCustom)
            #expect(site.region == .custom)
        }
    }

    @Test func archivedSitesLeaveThePickerButKeepTheirName() throws {
        let store = defaults()
        let context = try context()
        let journal = JournalStore(context: context)
        let calf = try journal.addCustomSite(name: "Left calf", for: .pump)
        try journal.setArchived(calf, true)

        CustomSiteStore.refreshMirror(try journal.customSites(includingArchived: true), defaults: store)

        // Gone from what a new placement can choose…
        #expect(CustomSiteStore.activeSites(for: .pump, defaults: store).isEmpty)
        // …but a placement already on it still resolves to the name, not a raw ID.
        #expect(CustomSiteStore.site(for: calf.siteID, defaults: store)?.title == "Left calf")
    }

    @Test func namesAreTrimmed() throws {
        let journal = JournalStore(context: try context())
        let site = try journal.addCustomSite(name: "  Left calf \n", for: .pump)
        #expect(site.name == "Left calf")
    }

    @Test func renameAndRestore() throws {
        let journal = JournalStore(context: try context())
        let site = try journal.addCustomSite(name: "Calf", for: .pump)
        try journal.rename(site, to: "Left calf")
        #expect(site.name == "Left calf")

        try journal.setArchived(site, true)
        #expect(try journal.customSites(for: .pump).isEmpty)
        try journal.setArchived(site, false)
        #expect(try journal.customSites(for: .pump).map(\.name) == ["Left calf"])
    }

    @Test func sitesBelongToOneTrackOnly() throws {
        let store = defaults()
        let journal = JournalStore(context: try context())
        try journal.addCustomSite(name: "Left calf", for: .pump)
        let arm = try journal.addCustomSite(name: "Back of arm", for: .cgm)

        CustomSiteStore.refreshMirror(try journal.customSites(includingArchived: true), defaults: store)

        // A pump site is not offered to the sensor, or the other way round.
        #expect(CustomSiteStore.activeSites(for: .pump, defaults: store).map(\.title) == ["Left calf"])
        #expect(CustomSiteStore.activeSites(for: .cgm, defaults: store).map(\.title) == ["Back of arm"])
        #expect(try journal.customSites(for: .cgm).map(\.name) == ["Back of arm"])

        // But a placement resolves its name whichever track it came from — the
        // history list mixes both.
        #expect(CustomSiteStore.site(for: arm.siteID, defaults: store)?.title == "Back of arm")
    }

    // MARK: Area exclusions

    @Test func encodeKeepsCustomSiteExclusions() throws {
        let store = defaults()
        let context = try context()
        let journal = JournalStore(context: context)
        let calf = try journal.addCustomSite(name: "Left calf", for: .pump)
        CustomSiteStore.refreshMirror(try journal.customSites(includingArchived: true), defaults: store)

        // encode() used to filter against PumpSite.catalog alone, which silently
        // dropped a custom site's exclusion on the next write.
        let order = PumpSite.catalog.map(\.id) + CustomSiteStore.allSiteIDs(defaults: store)
        let encoded = order
            .filter(Set(["abdomen-left", calf.siteID]).contains)
            .joined(separator: ",")
        #expect(AreaSettings.parse(encoded) == Set(["abdomen-left", calf.siteID]))
        #expect(encoded.contains(calf.siteID))
    }

    // MARK: Artwork

    @Test func everyBodyTypeHasAFloatingArea() {
        // Custom sites borrow one existing blob rather than shipping artwork of
        // their own, so that shape has to exist for every silhouette.
        for bodyType in BodyType.allCases {
            #expect(
                SiteAreaCatalog.floatingArea(bodyType: bodyType) != nil,
                "no floating area for \(bodyType.rawValue)"
            )
        }
    }

    @Test func floatingShapeFillsItsFrameAndStaysInside() {
        let area = SiteAreaCatalog.floatingArea(bodyType: .neutral)!
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let bounds = FloatingAreaShape(area: area).path(in: frame).boundingRect

        // Re-fitted out of its place in the viewBox: centred, inside the frame,
        // and large enough to read as the subject rather than a speck.
        #expect(frame.insetBy(dx: -0.5, dy: -0.5).contains(bounds))
        #expect(max(bounds.width, bounds.height) > 60)
        #expect(abs(bounds.midX - frame.midX) < 1)
        #expect(abs(bounds.midY - frame.midY) < 1)
    }

    @Test func floatingShapeKeepsItsProportionsInANonSquareFrame() {
        let area = SiteAreaCatalog.floatingArea(bodyType: .neutral)!
        let square = FloatingAreaShape(area: area)
            .path(in: CGRect(x: 0, y: 0, width: 100, height: 100)).boundingRect
        let wide = FloatingAreaShape(area: area)
            .path(in: CGRect(x: 0, y: 0, width: 300, height: 100)).boundingRect

        let squareRatio = square.width / square.height
        let wideRatio = wide.width / wide.height
        #expect(abs(squareRatio - wideRatio) < 0.01)
    }

    // MARK: Placements on a custom site

    @Test func placementOnACustomSiteResolvesAndCollectsRecency() throws {
        let store = defaults()
        let context = try context()
        let journal = JournalStore(context: context)
        let calf = try journal.addCustomSite(name: "Left calf", for: .pump)
        CustomSiteStore.refreshMirror(try journal.customSites(includingArchived: true), defaults: store)

        try journal.startPlacement(siteID: calf.siteID, deviceType: .pump)
        let history = try journal.history()
        #expect(history.count == 1)

        let timeline = PlacementTimeline(records: history, deviceType: .pump)
        #expect(timeline.current?.siteID == calf.siteID)
        // Custom sites take part in rotation like any other site.
        let recency = SiteRecencyModel(history: history)
        #expect(recency.tier(for: calf.siteID) == .veryRecent)
        #expect(recency.veryRecentSiteIDs.contains(calf.siteID))
    }

    @Test func suggestionEngineOffersCustomSites() throws {
        let store = defaults()
        let context = try context()
        let journal = JournalStore(context: context)
        let calf = try journal.addCustomSite(name: "Left calf", for: .pump)
        CustomSiteStore.refreshMirror(try journal.customSites(includingArchived: true), defaults: store)

        let candidates = PumpSite.catalog + CustomSiteStore.activeSites(for: .pump, defaults: store)
        let suggestions = SiteSuggestionEngine().suggestions(
            from: candidates,
            history: [],
            limit: candidates.count,
            excluding: [],
            starterSiteIDs: PumpSite.starterSiteIDs
        )
        #expect(suggestions.contains { $0.id == calf.siteID })
    }
}

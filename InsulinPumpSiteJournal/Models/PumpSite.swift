import Foundation
import CoreGraphics

struct PumpSite: Identifiable, Hashable {
    enum BodyView {
        case front
        case rear
    }

    let id: String
    let title: String
    let shortTitle: String
    let bodyView: BodyView
    let markerPosition: CGPoint
    let region: Region

    enum Region: String {
        case abdomen
        case arm
        case thigh
        case lowerBack
        case upperButtock
    }
}

extension PumpSite {
    /// The compile-time site catalog. Order is significant: it is the stable
    /// tie-breaker used by `SiteSuggestionEngine`. Site IDs match the
    /// mounting-area asset names (see `SiteAreaCatalog`).
    ///
    /// All left/right names are the WEARER's left/right. On the front view
    /// the wearer's left renders on the viewer's right (mirror image); on the
    /// rear view (standard posterior anatomy) wearer-left and viewer-left
    /// coincide. `markerPosition` is the normalized centroid of the site's
    /// mounting area — the dot-marker fallback for body types without area
    /// assets, and the card zoom anchor.
    static let catalog: [PumpSite] = [
        PumpSite(
            id: "abdomen-left",
            title: "Left abdomen",
            shortTitle: "Left Abdomen",
            bodyView: .front,
            markerPosition: CGPoint(x: 0.625, y: 0.391),
            region: .abdomen
        ),
        PumpSite(
            id: "abdomen-right",
            title: "Right abdomen",
            shortTitle: "Right Abdomen",
            bodyView: .front,
            markerPosition: CGPoint(x: 0.375, y: 0.391),
            region: .abdomen
        ),
        PumpSite(
            id: "front-thigh-left",
            title: "Left front thigh",
            shortTitle: "Left Front Thigh",
            bodyView: .front,
            markerPosition: CGPoint(x: 0.660, y: 0.587),
            region: .thigh
        ),
        PumpSite(
            id: "front-thigh-right",
            title: "Right front thigh",
            shortTitle: "Right Front Thigh",
            bodyView: .front,
            markerPosition: CGPoint(x: 0.340, y: 0.587),
            region: .thigh
        ),
        PumpSite(
            id: "back-upper-arm-left",
            title: "Left upper arm",
            shortTitle: "Left Arm",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.244, y: 0.275),
            region: .arm
        ),
        PumpSite(
            id: "back-upper-arm-right",
            title: "Right upper arm",
            shortTitle: "Right Arm",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.756, y: 0.275),
            region: .arm
        ),
        PumpSite(
            id: "lower-back-left",
            title: "Left lower back",
            shortTitle: "Left Lower Back",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.396, y: 0.393),
            region: .lowerBack
        ),
        PumpSite(
            id: "lower-back-right",
            title: "Right lower back",
            shortTitle: "Right Lower Back",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.604, y: 0.393),
            region: .lowerBack
        ),
        PumpSite(
            id: "outer-thigh-left",
            title: "Left outer thigh",
            shortTitle: "Left Outer Thigh",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.335, y: 0.588),
            region: .thigh
        ),
        PumpSite(
            id: "outer-thigh-right",
            title: "Right outer thigh",
            shortTitle: "Right Outer Thigh",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.665, y: 0.588),
            region: .thigh
        ),
        PumpSite(
            id: "upper-buttock-left",
            title: "Left upper buttock",
            shortTitle: "Left Buttock",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.337, y: 0.475),
            region: .upperButtock
        ),
        PumpSite(
            id: "upper-buttock-right",
            title: "Right upper buttock",
            shortTitle: "Right Buttock",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.663, y: 0.475),
            region: .upperButtock
        ),
    ]

    /// Starter suggestions for an empty history: four sites across four
    /// distinct regions, in a fixed order.
    static let starterSiteIDs: [String] = [
        "abdomen-left",
        "back-upper-arm-right",
        "front-thigh-left",
        "lower-back-right",
    ]

    // MARK: - CGM sensor track
    //
    // The sensor vertical reuses the pump catalog's geometry: its sites are a
    // subset of the same entries (same IDs, marker centroids, and baked area
    // paths in `SiteAreaCatalog`), so no new artwork is needed. Only the set of
    // approved sensor sites differs — back of upper arm, abdomen, and upper
    // buttock. Order is significant (the suggestion engine's stable tie-break):
    // arm first (the primary site), then abdomen, then buttock.
    static let cgmSiteIDs: [String] = [
        "back-upper-arm-left",
        "back-upper-arm-right",
        "abdomen-left",
        "abdomen-right",
        "upper-buttock-left",
        "upper-buttock-right",
    ]

    /// The sensor site catalog, derived from the shared `catalog` in
    /// `cgmSiteIDs` order.
    static let cgmCatalog: [PumpSite] = cgmSiteIDs.compactMap { id in
        catalog.first { $0.id == id }
    }

    /// Starter sensor suggestions for an empty history: spread across the
    /// three sensor regions.
    static let cgmStarterSiteIDs: [String] = [
        "back-upper-arm-left",
        "abdomen-right",
        "upper-buttock-left",
        "back-upper-arm-right",
    ]

    /// The site catalog for a device track.
    static func sites(for device: DeviceType) -> [PumpSite] {
        switch device {
        case .pump: catalog
        case .cgm: cgmCatalog
        }
    }

    /// The empty-history starter IDs for a device track.
    static func starterSiteIDs(for device: DeviceType) -> [String] {
        switch device {
        case .pump: starterSiteIDs
        case .cgm: cgmStarterSiteIDs
        }
    }

    private static let byID: [String: PumpSite] = Dictionary(
        uniqueKeysWithValues: catalog.map { ($0.id, $0) }
    )

    static func site(for id: String) -> PumpSite? {
        byID[SiteID.canonical(id)]
    }
}

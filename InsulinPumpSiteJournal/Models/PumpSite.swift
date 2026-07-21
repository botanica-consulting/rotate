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
    /// tie-breaker used by `SiteSuggestionEngine`.
    ///
    /// All left/right names are the WEARER's left/right. On the front
    /// silhouette the wearer's left renders on the viewer's right (mirror
    /// image); on the rear silhouette wearer-left and viewer-left coincide.
    /// `markerPosition` values are normalized to the silhouette's unit rect
    /// and encode that mirroring.
    static let catalog: [PumpSite] = [
        PumpSite(
            id: "abdomen-upper-left",
            title: "Upper-left abdomen",
            shortTitle: "Upper-Left Abdomen",
            bodyView: .front,
            markerPosition: CGPoint(x: 0.60, y: 0.37),
            region: .abdomen
        ),
        PumpSite(
            id: "abdomen-upper-right",
            title: "Upper-right abdomen",
            shortTitle: "Upper-Right Abdomen",
            bodyView: .front,
            markerPosition: CGPoint(x: 0.40, y: 0.37),
            region: .abdomen
        ),
        PumpSite(
            id: "abdomen-lower-left",
            title: "Lower-left abdomen",
            shortTitle: "Lower-Left Abdomen",
            bodyView: .front,
            markerPosition: CGPoint(x: 0.585, y: 0.46),
            region: .abdomen
        ),
        PumpSite(
            id: "abdomen-lower-right",
            title: "Lower-right abdomen",
            shortTitle: "Lower-Right Abdomen",
            bodyView: .front,
            markerPosition: CGPoint(x: 0.415, y: 0.46),
            region: .abdomen
        ),
        PumpSite(
            id: "thigh-left",
            title: "Left thigh",
            shortTitle: "Left Thigh",
            bodyView: .front,
            markerPosition: CGPoint(x: 0.61, y: 0.60),
            region: .thigh
        ),
        PumpSite(
            id: "thigh-right",
            title: "Right thigh",
            shortTitle: "Right Thigh",
            bodyView: .front,
            markerPosition: CGPoint(x: 0.39, y: 0.60),
            region: .thigh
        ),
        PumpSite(
            id: "arm-upper-left",
            title: "Left upper arm",
            shortTitle: "Left Arm",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.26, y: 0.28),
            region: .arm
        ),
        PumpSite(
            id: "arm-upper-right",
            title: "Right upper arm",
            shortTitle: "Right Arm",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.74, y: 0.28),
            region: .arm
        ),
        PumpSite(
            id: "lower-back-left",
            title: "Left lower back",
            shortTitle: "Left Lower Back",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.41, y: 0.42),
            region: .lowerBack
        ),
        PumpSite(
            id: "lower-back-right",
            title: "Right lower back",
            shortTitle: "Right Lower Back",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.59, y: 0.42),
            region: .lowerBack
        ),
        PumpSite(
            id: "buttock-upper-left",
            title: "Left upper buttock",
            shortTitle: "Left Buttock",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.40, y: 0.51),
            region: .upperButtock
        ),
        PumpSite(
            id: "buttock-upper-right",
            title: "Right upper buttock",
            shortTitle: "Right Buttock",
            bodyView: .rear,
            markerPosition: CGPoint(x: 0.60, y: 0.51),
            region: .upperButtock
        ),
    ]

    /// Starter suggestions for an empty history: four sites across four
    /// distinct regions, in a fixed order.
    static let starterSiteIDs: [String] = [
        "abdomen-upper-left",
        "arm-upper-right",
        "thigh-left",
        "lower-back-right",
    ]

    private static let byID: [String: PumpSite] = Dictionary(
        uniqueKeysWithValues: catalog.map { ($0.id, $0) }
    )

    static func site(for id: String) -> PumpSite? {
        byID[id]
    }
}

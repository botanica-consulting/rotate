import Foundation
import Testing
@testable import InsulinPumpSiteJournal

struct SiteAreaCatalogTests {
    @Test(arguments: BodyType.allCases)
    func everyBodyTypeHasAnAreaForEveryCatalogSite(bodyType: BodyType) {
        for site in PumpSite.catalog {
            #expect(
                SiteAreaCatalog.area(for: site.id, bodyType: bodyType) != nil,
                "missing \(bodyType.rawValue) area for \(site.id)"
            )
        }
    }

    @Test func areaPathsParseToNonEmptyBoundedShapes() {
        for (_, sites) in SiteAreaCatalog.areas {
            for (siteID, area) in sites {
                let path = SVGPathParser.path(from: area.pathData)
                let bounds = path.boundingRect
                #expect(!path.isEmpty, "empty path for \(siteID)")
                #expect(bounds.width > 5 && bounds.height > 5, "degenerate bounds for \(siteID)")
                #expect(
                    bounds.minX >= 0 && bounds.minY >= 0
                        && bounds.maxX <= area.viewBoxWidth
                        && bounds.maxY <= area.viewBoxHeight,
                    "path escapes viewBox for \(siteID)"
                )
            }
        }
    }

    /// Wearer-relative sides: on the FRONT the wearer's left renders on the
    /// viewer's right (mirror); on the REAR (standard posterior anatomy) the
    /// wearer's left renders on the viewer's left. Verifies the generator's
    /// rear left/right remap for every body type.
    @Test(arguments: BodyType.allCases)
    func areaSidesMatchWearerAnatomy(bodyType: BodyType) {
        for site in PumpSite.catalog {
            guard let area = SiteAreaCatalog.area(for: site.id, bodyType: bodyType) else { continue }
            let mid = SVGPathParser.path(from: area.pathData).boundingRect.midX
            let onViewerRight = mid > area.viewBoxWidth / 2
            let isWearerLeft = site.id.contains("-left")
            let expectedViewerRight = site.bodyView == .front ? isWearerLeft : !isWearerLeft
            #expect(
                onViewerRight == expectedViewerRight,
                "\(site.id) renders on the wrong side (midX \(mid))"
            )
        }
    }
}

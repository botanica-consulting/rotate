import SwiftUI

extension SiteAreaCatalog {
    /// The shape every custom site borrows.
    ///
    /// Custom sites have no artwork of their own — we can't know where on the
    /// body the user means — so they reuse one existing mounting-area blob,
    /// drawn free-floating. The upper buttock is the roundest, least
    /// obviously-anatomical of the twelve, so it reads as "a patch of skin"
    /// rather than as a specific place.
    static func floatingArea(bodyType: BodyType) -> SiteArea? {
        area(for: "upper-buttock-left", bodyType: bodyType)
    }
}

/// A custom site's stand-in for the body figure: the area shape alone, in the
/// same recency-tinted fill and hairline outline every other site gets, with no
/// silhouette under it.
struct CustomSiteThumbnail: View {
    let fill: Color
    /// When set, marks the site with that device's badge, as the figures do.
    var badgeDevice: DeviceType? = nil

    @AppStorage(BodyType.storageKey) private var bodyTypeRaw = BodyType.neutral.rawValue

    private var bodyType: BodyType {
        BodyType(rawValue: bodyTypeRaw) ?? .neutral
    }

    var body: some View {
        ZStack {
            if let area = SiteAreaCatalog.floatingArea(bodyType: bodyType) {
                let shape = FloatingAreaShape(area: area)
                shape
                    .fill(fill.opacity(AppTheme.areaFillOpacity))
                    .overlay(shape.stroke(AppTheme.areaOutline, lineWidth: AppTheme.areaLineWidth))
            }
            if let badgeDevice {
                CurrentSiteBadge(device: badgeDevice)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview("Custom site") {
    HStack(spacing: 24) {
        CustomSiteThumbnail(fill: AppTheme.restedShade)
            .frame(width: 120, height: 120)
        CustomSiteThumbnail(fill: AppTheme.stale, badgeDevice: .pump)
            .frame(width: 120, height: 120)
    }
    .padding()
}

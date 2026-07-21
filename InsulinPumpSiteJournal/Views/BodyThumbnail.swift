import SwiftUI

/// A front or rear body figure (SVG line art, per the selected body type)
/// with the site's area highlighted using the same recency language as the
/// body map. `zoom` scales the figure toward the marker so cards emphasize
/// the area while keeping enough of the body visible for context; the
/// parent clips the overflow.
struct BodyThumbnail: View {
    let site: PumpSite
    let fill: Color
    var zoom: CGFloat = 1
    /// When true, the zoom recenters the figure so the site's area lands in
    /// the middle of the frame instead of staying anchored in place.
    var centerOnMarker: Bool = false

    @AppStorage(BodyType.storageKey) private var bodyTypeRaw = BodyType.neutral.rawValue

    private var bodyType: BodyType {
        BodyType(rawValue: bodyTypeRaw) ?? .neutral
    }

    var body: some View {
        Image(bodyType.assetName(for: site.bodyView))
            .resizable()
            .scaledToFit()
            .opacity(AppTheme.silhouetteOpacity)
            .overlay {
                GeometryReader { geometry in
                    if let area = SiteAreaCatalog.area(for: site.id, bodyType: bodyType) {
                        SiteAreaHighlight(area: area, fill: fill, displayScale: zoom)
                    } else {
                        // No area asset for this body type yet: dot fallback.
                        Circle()
                            .fill(fill)
                            .overlay(Circle().stroke(.background, lineWidth: 2))
                            .frame(width: 18, height: 18)
                            .position(
                                x: geometry.size.width * site.markerPosition.x,
                                y: geometry.size.height * site.markerPosition.y
                            )
                    }
                }
            }
            .scaleEffect(zoom, anchor: zoomAnchor)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription)
    }

    /// Anchored zoom keeps the area where it sits; centered zoom solves
    /// `anchor + zoom * (marker - anchor) = center` so the area lands mid-
    /// frame. Anchors outside 0...1 are valid.
    private var zoomAnchor: UnitPoint {
        let marker = site.markerPosition
        guard centerOnMarker, zoom != 1 else {
            return UnitPoint(x: marker.x, y: marker.y)
        }
        return UnitPoint(
            x: (0.5 - zoom * marker.x) / (1 - zoom),
            y: (0.5 - zoom * marker.y) / (1 - zoom)
        )
    }

    private var accessibilityDescription: String {
        let view = site.bodyView == .front ? "Front" : "Rear"
        return "\(view) body view, \(site.title.lowercased()) highlighted."
    }
}

#Preview("Thumbnails") {
    HStack(spacing: 24) {
        BodyThumbnail(site: PumpSite.catalog[0], fill: AppTheme.restedShade)
            .frame(height: 160)
        BodyThumbnail(site: PumpSite.catalog[7], fill: AppTheme.recent)
            .frame(height: 160)
    }
    .padding()
}

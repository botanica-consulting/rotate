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
    /// When set, draws that device's badge on the site's area — inside the
    /// scaled figure so it tracks the zoom (and its animation) and lands on
    /// the marker, but counter-scaled so it stays a fixed size like the body
    /// map's markers.
    var badgeDevice: DeviceType? = nil

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
                        // Defensive dot fallback for a site with no area asset
                        // (every catalog site currently has one). Sized against
                        // the zoom so the dot stays 18pt however far it scales.
                        Circle()
                            .fill(fill)
                            .overlay(Circle().stroke(.background, lineWidth: 2 / zoom))
                            .frame(width: 18 / zoom, height: 18 / zoom)
                            .position(
                                x: geometry.size.width * site.markerPosition.x,
                                y: geometry.size.height * site.markerPosition.y
                            )
                    }

                    if let badgeDevice {
                        // Inside the scaled figure and NOT counter-scaled, so
                        // the badge grows and shrinks with the zoom just like
                        // the area under it; positioned on the marker so it
                        // rides the zoom to wherever the area lands. The base
                        // scale keeps it proportional to the compact figure.
                        CurrentSiteBadge(device: badgeDevice)
                            .scaleEffect(AppTheme.currentBadgeCardScale)
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

/// A BodyThumbnail zoomed onto its site with the standard soft radial crop.
/// One place owns the vignette geometry so the current-Pod card and the
/// record sheet render it identically at any frame size.
struct VignettedBodyThumbnail: View {
    let site: PumpSite
    let fill: Color
    /// When set, marks the site with the same miniature device badge the body
    /// map uses. The centered zoom lands the marker at the frame's center, so
    /// the badge sits on the area with no extra positioning.
    var device: DeviceType? = nil

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            BodyThumbnail(
                site: site,
                fill: fill,
                zoom: AppTheme.siteFocusZoom,
                centerOnMarker: true
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .mask {
                RadialGradient(
                    colors: [.black, .black, .clear],
                    center: .center,
                    startRadius: side * AppTheme.vignetteInnerRatio,
                    endRadius: side * AppTheme.vignetteOuterRatio
                )
            }
            .overlay {
                if let device {
                    // Scale the fixed-size badge down: the card is a small,
                    // tightly-cropped view, so the full-size Pod/sensor looms
                    // over the compact figure. Shrinking keeps it proportional.
                    CurrentSiteBadge(device: device)
                        .scaleEffect(AppTheme.currentBadgeCardScale)
                        .accessibilityHidden(true)
                }
            }
        }
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

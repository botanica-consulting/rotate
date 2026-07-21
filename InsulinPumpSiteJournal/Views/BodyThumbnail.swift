import SwiftUI

/// A front or rear body figure (SVG line art, per the selected body type)
/// with the site's marker overlaid at its normalized position. `zoom` scales
/// the figure toward the marker so cards emphasize the area while keeping
/// enough of the body visible for context; the parent clips the overflow.
struct BodyThumbnail: View {
    let site: PumpSite
    var markerColor: Color = AppTheme.accent
    var zoom: CGFloat = 1

    @AppStorage(BodyType.storageKey) private var bodyTypeRaw = BodyType.neutral.rawValue

    private var bodyType: BodyType {
        BodyType(rawValue: bodyTypeRaw) ?? .neutral
    }

    var body: some View {
        Image(bodyType.assetName(for: site.bodyView))
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geometry in
                    Circle()
                        .fill(markerColor)
                        .overlay(Circle().stroke(.background, lineWidth: 2))
                        .frame(width: 18, height: 18)
                        .position(
                            x: geometry.size.width * site.markerPosition.x,
                            y: geometry.size.height * site.markerPosition.y
                        )
                }
            }
            .scaleEffect(
                zoom,
                anchor: UnitPoint(x: site.markerPosition.x, y: site.markerPosition.y)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let view = site.bodyView == .front ? "Front" : "Rear"
        return "\(view) body view, \(site.title.lowercased()) highlighted."
    }
}

#Preview("Thumbnails") {
    HStack(spacing: 24) {
        BodyThumbnail(site: PumpSite.catalog[0])
            .frame(height: 160)
        BodyThumbnail(site: PumpSite.catalog[7], markerColor: AppTheme.recent)
            .frame(height: 160)
    }
    .padding()
}

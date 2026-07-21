import SwiftUI

/// A front or rear body silhouette with the site's marker overlaid at its
/// normalized position. Plain, high-contrast surface — never under glass.
struct BodyThumbnail: View {
    let site: PumpSite
    var markerColor: Color = AppTheme.accent

    var body: some View {
        GeometryReader { geometry in
            let silhouette = BodySilhouette(bodyView: site.bodyView)
            silhouette
                .fill(Color.primary.opacity(0.22))
                .overlay(silhouette.stroke(Color.primary.opacity(0.45), lineWidth: 1))
                .overlay {
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
        .aspectRatio(0.45, contentMode: .fit)
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

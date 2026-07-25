import SwiftUI

/// One of the four suggestion cards. Unselected cards sit on a plain
/// high-contrast surface; the selected card receives the Liquid Glass
/// treatment and a checkmark badge so selection is never color-only.
struct SiteSuggestionCard: View {
    let site: PumpSite
    let lastUsed: Date?
    let tier: SiteRecencyModel.Tier
    let isSelected: Bool
    let index: Int
    /// When a device currently sits on this site, the card is rendered like the
    /// current-site card — zoomed into the area with that device's badge — so
    /// the grid shows what's already on the body, correctly located.
    var occupiedBy: DeviceType? = nil
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let thumbnailHeight: CGFloat = 140
    /// Unselected cards stay lightly zoomed toward the site for context.
    private let restingZoom: CGFloat = 1.35

    /// The card's figure. An occupied site reuses the current-site card's
    /// vignette + device badge (centered, zoomed onto the area) so the badge
    /// lands on the right spot; every other card keeps the resting-zoom body
    /// that zooms in only when selected.
    @ViewBuilder
    private var thumbnail: some View {
        if let occupiedBy {
            // Tint the area with the occupying device's own color (pump blue /
            // sensor teal) rather than its recency shade, so "a device is here
            // now" reads at a glance and names which device.
            VignettedBodyThumbnail(
                site: site,
                fill: AppTheme.tint(for: occupiedBy),
                device: occupiedBy
            )
            .frame(height: thumbnailHeight)
            .frame(maxWidth: .infinity)
        } else {
            BodyThumbnail(
                site: site,
                fill: AppTheme.color(for: tier),
                zoom: isSelected ? AppTheme.siteFocusZoom : restingZoom,
                centerOnMarker: isSelected
            )
            .frame(height: thumbnailHeight)
            .frame(maxWidth: .infinity)
            .clipped()
            // Vignette: selection zooms into the area and softly crops the
            // sides. Both masks stay in the tree so the switch cross-fades
            // with the zoom animation.
            .mask {
                ZStack {
                    Rectangle()
                        .opacity(isSelected ? 0 : 1)
                    RadialGradient(
                        colors: [.black, .black, .clear],
                        center: .center,
                        startRadius: thumbnailHeight * AppTheme.vignetteInnerRatio,
                        endRadius: thumbnailHeight * AppTheme.vignetteOuterRatio
                    )
                    .opacity(isSelected ? 1 : 0)
                }
            }
            // The zoom gets its own settle-in spring; the rest of the
            // selection treatment keeps the flow's quick fade.
            .animation(
                reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8),
                value: isSelected
            )
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                thumbnail

                Text(site.bodyView == .front ? "Front" : "Rear")
                    .font(.caption2.smallCaps())
                    .foregroundStyle(.secondary)

                Text(site.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if let lastUsed {
                    Text("Last used \(lastUsed.formatted(.relative(presentation: .named)))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                        .padding(10)
                }
            }
            .contentShape(.rect(cornerRadius: AppTheme.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .background {
            if !isSelected {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(.thinMaterial)
            } else if reduceTransparency {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(.thickMaterial)
            }
        }
        .modifier(SelectionGlass(isSelected: isSelected))
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("suggestionCard-\(index)")
    }

    private var accessibilityDescription: String {
        var parts = [
            site.title,
            site.bodyView == .front ? "front body view" : "rear body view",
        ]
        if let lastUsed {
            parts.append("last used \(lastUsed.formatted(date: .abbreviated, time: .omitted))")
        } else {
            parts.append("not used before")
        }
        if let occupiedBy {
            parts.append("\(occupiedBy.noun) currently here")
        }
        return parts.joined(separator: ", ")
    }
}

/// Applies the Liquid Glass selection treatment. Selection changes are a
/// plain quick fade — no morph or scale, which read as sluggish when moving
/// between cards. The modifier stays in the tree and toggles via `isEnabled`:
/// an if/else here would change the card's view identity on selection, which
/// resets the thumbnail instead of animating its zoom.
private struct SelectionGlass: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content.background {
            Color.clear
                .glassEffect(
                    .regular.tint(AppTheme.accent.opacity(0.45)).interactive(),
                    in: .rect(cornerRadius: AppTheme.cardCornerRadius)
                )
                .opacity(isSelected ? 1 : 0)
        }
    }
}

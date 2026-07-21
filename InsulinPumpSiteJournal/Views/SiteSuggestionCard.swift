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
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    BodyThumbnail(site: site, markerColor: AppTheme.color(for: tier))
                        .frame(height: 130)
                    Spacer()
                }

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
        return parts.joined(separator: ", ")
    }
}

/// Applies the Liquid Glass selection treatment. Selection changes are a
/// plain quick fade — no morph or scale, which read as sluggish when moving
/// between cards.
private struct SelectionGlass: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if isSelected {
            content
                .glassEffect(
                    .regular.tint(AppTheme.accent.opacity(0.45)).interactive(),
                    in: .rect(cornerRadius: AppTheme.cardCornerRadius)
                )
        } else {
            content
        }
    }
}

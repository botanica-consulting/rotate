import SwiftUI
import WidgetKit

/// One readout per family. Lock-screen accessories are rendered monochrome, so
/// the tint only shows on the home-screen widget — the hour count and the site
/// name carry the meaning either way.
struct SiteAgeWidgetView: View {
    let entry: SiteAgeEntry

    @Environment(\.widgetFamily) private var family

    private var hours: String? {
        entry.placedAt.map { WearDuration.text(at: entry.date, since: $0) }
    }

    private var spoken: String {
        guard let placedAt = entry.placedAt else {
            return "No \(entry.device.noun) site recorded. Tap to start one."
        }
        let age = WearDuration.spokenText(at: entry.date, since: placedAt)
        let site = entry.siteTitle.map { ", on your \($0.lowercased())" } ?? ""
        return "\(entry.device.displayName) on \(age)\(site)."
    }

    var body: some View {
        content
            .widgetURL(DeepLink.newPlacement(for: entry.device))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            // One line, no styling allowed: the track name is the only context
            // that fits alongside the number.
            Text("\(entry.device.displayName) \(hours ?? "—")")

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -1) {
                    Text(hours ?? "—")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .minimumScaleFactor(0.6)
                    Text(entry.device.displayName.uppercased())
                        .font(.system(size: 8).weight(.semibold))
                        .opacity(0.7)
                }
            }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.device.displayName.uppercased())
                    .font(.caption2.weight(.semibold))
                    .opacity(0.7)
                Text(hours ?? "No site")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Text(entry.siteTitle ?? "Tap to start")
                    .font(.caption2)
                    .opacity(0.8)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        default:
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.device.displayName.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(hours ?? "—")
                    .font(.system(size: 40, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.tint(for: entry.device))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(entry.siteTitle ?? "Tap to start a site")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

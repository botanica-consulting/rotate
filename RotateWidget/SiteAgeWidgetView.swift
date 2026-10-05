import SwiftUI
import WidgetKit

/// The site-age readout, one composition per family.
///
/// Two things drive the design. First, it has to be the app's readout, not a
/// generic one: the hour count is set in the same monospaced face
/// `PodAgeCounter` uses, and the track is identified by the same Pod and
/// sensor marks that sit on the body map — so the widget reads as Rotate at a
/// glance. Second, lock-screen accessories render monochrome, so colour can
/// carry no meaning there; the mark's silhouette is what separates pump from
/// sensor, and the tint only comes back on the home-screen family.
struct SiteAgeWidgetView: View {
    let entry: SiteAgeEntry

    @Environment(\.widgetFamily) private var family

    private var hours: Int? {
        entry.placedAt.map { WearDuration.hours(at: entry.date, since: $0) }
    }

    private var tint: Color { AppTheme.tint(for: entry.device) }

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
            .containerBackground(for: .widget) { background }
            .widgetURL(DeepLink.newPlacement(for: entry.device))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken)
    }

    /// Only the home-screen family gets a ground of its own — an accessory
    /// draws onto the wallpaper and has to stay clear of it.
    @ViewBuilder
    private var background: some View {
        if family == .systemSmall {
            LinearGradient(
                colors: [tint.opacity(0.20), tint.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            // A single system-styled line: no mark, no layout, so the words
            // have to do all of it.
            Text(inlineText)

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    CurrentSiteBadge(device: entry.device, scale: 0.66)
                        .widgetAccentable()
                    AgeReadout(hours: hours, size: 22)
                }
                .padding(.horizontal, 6)
            }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                trackRow(fontSize: 10, badgeScale: 0.52)
                    .opacity(0.75)
                    .widgetAccentable()
                AgeReadout(hours: hours, size: 25)
                Text(entry.siteTitle ?? "Tap to start")
                    .font(.system(size: 11))
                    .opacity(0.75)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        default:
            VStack(alignment: .leading, spacing: 0) {
                trackRow(fontSize: 11, badgeScale: 0.8)
                    .foregroundStyle(tint)

                Spacer(minLength: 6)

                AgeReadout(hours: hours, size: 46)
                    .foregroundStyle(tint)

                Spacer(minLength: 4)

                Text(entry.siteTitle ?? "Tap to start a site")
                    .font(.footnote.weight(.medium))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if let placedAt = entry.placedAt {
                    Text("since \(placedAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    /// The mark plus the track name — the app's own way of saying which of the
    /// two timelines this is.
    private func trackRow(fontSize: CGFloat, badgeScale: CGFloat) -> some View {
        HStack(spacing: 4) {
            CurrentSiteBadge(device: entry.device, scale: badgeScale)
            Text(entry.device.displayName.uppercased())
                .font(.system(size: fontSize, weight: .semibold))
                .tracking(0.6)
        }
    }

    private var inlineText: String {
        guard let hours else { return "\(entry.device.displayName) — no site" }
        guard let site = entry.siteTitle else { return "\(entry.device.displayName) \(hours)h" }
        return "\(entry.device.displayName) \(hours)h · \(site)"
    }
}

/// The hour count, set like the app's `PodAgeCounter`: monospaced figures with
/// the unit dropped to a subordinate size on the same baseline, so the number
/// is what the eye lands on.
private struct AgeReadout: View {
    let hours: Int?
    let size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(hours.map(String.init) ?? "—")
                .font(.system(size: size, weight: .semibold, design: .monospaced))
            if hours != nil {
                Text("h")
                    .font(.system(size: size * 0.52, weight: .semibold, design: .monospaced))
                    .opacity(0.6)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

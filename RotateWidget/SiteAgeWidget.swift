import SwiftUI
import WidgetKit

struct SiteAgeEntry: TimelineEntry {
    let date: Date
    let device: DeviceType
    /// nil when nothing is on that track.
    let placedAt: Date?
    let siteTitle: String?
}

/// Reads the snapshot the app publishes, then works the hour count out locally.
///
/// The timeline carries one entry per hour boundary, so the number advances on
/// the lock screen without the app being woken — the snapshot only has to be
/// rewritten when the *site* changes, not when the clock moves.
struct SiteAgeProvider: AppIntentTimelineProvider {
    /// A day of hourly entries. WidgetKit will ask again well before they run
    /// out; the `.after` policy is the backstop.
    private static let entryCount = 24

    func placeholder(in context: Context) -> SiteAgeEntry {
        SiteAgeEntry(
            date: .now,
            device: .pump,
            placedAt: Date.now.addingTimeInterval(-27 * 3600),
            siteTitle: "Left abdomen"
        )
    }

    func snapshot(for configuration: SelectTrackIntent, in context: Context) async -> SiteAgeEntry {
        entry(at: .now, device: configuration.device)
    }

    func timeline(for configuration: SelectTrackIntent, in context: Context) async -> Timeline<SiteAgeEntry> {
        let device = configuration.device
        let now = Date.now
        let first = entry(at: now, device: device)

        guard let placedAt = first.placedAt else {
            // Nothing on: no count to advance, so just check back in an hour.
            return Timeline(entries: [first], policy: .after(now.addingTimeInterval(3600)))
        }

        var entries = [first]
        var next = WearDuration.nextHourBoundary(after: now, since: placedAt)
        for _ in 0..<Self.entryCount {
            entries.append(
                SiteAgeEntry(date: next, device: device, placedAt: placedAt, siteTitle: first.siteTitle)
            )
            next = next.addingTimeInterval(3600)
        }
        return Timeline(entries: entries, policy: .after(next))
    }

    private func entry(at date: Date, device: DeviceType) -> SiteAgeEntry {
        let track = SiteSnapshot.load().track(for: device)
        return SiteAgeEntry(
            date: date,
            device: device,
            placedAt: track?.placedAt,
            siteTitle: track?.siteTitle
        )
    }
}

struct SiteAgeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "SiteAgeWidget",
            intent: SelectTrackIntent.self,
            provider: SiteAgeProvider()
        ) { entry in
            SiteAgeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Site age")
        .description("How long your current pump or sensor site has been on. Tap to start a new one.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .systemSmall,
        ])
    }
}

import Foundation
import WidgetKit

/// Keeps the shared snapshot (and so the widget) in step with the journal.
///
/// One hook, driven by `HistoryHomeView`'s `@Query`, covers every way the
/// current placement can change: a new site, a deletion, an edited time, or a
/// change merged in from another device through CloudKit.
@MainActor
enum SnapshotPublisher {
    /// `defaults` is injectable so tests don't write to the real shared suite.
    static func refresh(from records: [PlacementRecord], to defaults: UserDefaults = AppGroup.defaults) {
        var snapshot = SiteSnapshot()
        for device in DeviceType.allCases {
            guard let current = PlacementTimeline(records: records, deviceType: device).current else {
                continue
            }
            snapshot.setTrack(
                SiteSnapshot.Track(
                    placedAt: current.placedAt,
                    // Resolves custom sites too, so the widget shows a name
                    // rather than a raw ID.
                    siteTitle: PumpSite.site(for: current.siteID)?.title ?? current.siteID
                ),
                for: device
            )
        }

        // Writing unconditionally would reload every widget timeline on each
        // journal read, so only publish an actual change.
        guard snapshot != SiteSnapshot.load(from: defaults) else { return }
        SiteSnapshot.save(snapshot, to: defaults)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

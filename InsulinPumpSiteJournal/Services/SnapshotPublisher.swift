import Foundation
import WidgetKit

/// Keeps the shared snapshot (and so the widget) in step with the journal.
///
/// One hook, driven by `HistoryHomeView`'s `@Query`, covers every way the
/// current placement can change: a new site, a deletion, an edited time, or a
/// change merged in from another device through CloudKit.
@MainActor
enum SnapshotPublisher {
    /// `defaults` and `resolveTitle` are injectable so tests don't have to write
    /// to the real shared suite or the app-wide custom-site mirror.
    static func refresh(
        from records: [PlacementRecord],
        to defaults: UserDefaults = AppGroup.defaults,
        resolveTitle: (String) -> String = { PumpSite.site(for: $0)?.title ?? $0 }
    ) {
        var snapshot = SiteSnapshot()
        for device in DeviceType.allCases {
            guard let current = PlacementTimeline(records: records, deviceType: device).current else {
                continue
            }
            snapshot.setTrack(
                SiteSnapshot.Track(
                    placedAt: current.placedAt,
                    // Resolved here, in the app, so the widget is never handed a
                    // raw ID — including for custom sites, whose names only the
                    // app can look up.
                    siteTitle: resolveTitle(current.siteID)
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

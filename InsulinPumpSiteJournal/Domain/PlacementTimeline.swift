import Foundation

/// A validated, read-only view over placement history: canonical site IDs,
/// the current open placement, resolved stop dates, and wear statistics —
/// built in one pass so views never re-derive lifecycle rules.
///
/// Invariants it presents (the store enforces them on write; the timeline
/// also repairs display for pre-invariant data):
/// - "Current" means the newest record with `removedAt == nil`. Older open
///   records are treated as closed by the following placement.
/// - A resolved stop never precedes its start.
struct PlacementTimeline {
    struct Entry: Identifiable {
        let record: PlacementRecord
        /// Canonical site ID (legacy quadrant IDs remapped).
        let siteID: String
        let placedAt: Date
        /// Stamped or inferred stop; nil while the Pod is on.
        let stop: Date?

        var id: UUID { record.id }

        /// Which rotation track this entry belongs to — used to tag rows in
        /// the unified history list.
        var deviceType: DeviceType { DeviceType(rawValue: record.deviceType) ?? .pump }

        var wear: TimeInterval? {
            stop.map { max(0, $0.timeIntervalSince(placedAt)) }
        }
    }

    /// Newest first.
    let entries: [Entry]
    /// The Pod that is on right now, if any.
    let current: Entry?
    /// Most recent use per canonical site ID.
    let lastUsedBySite: [String: Date]

    /// Builds a timeline for a single device track, ignoring the other.
    init(records: [PlacementRecord], deviceType: DeviceType) {
        self.init(records: records.filter { $0.deviceType == deviceType.rawValue })
    }

    /// Resolves stops and `current` across *all* passed records as one track.
    /// Callers must pass a single device's records (use `init(records:deviceType:)`
    /// or `combinedEntries` for mixed data) — otherwise one track's newer
    /// placement would wrongly close the other's open one.
    init(records: [PlacementRecord]) {
        let sorted = records.sorted {
            Self.isNewer(placedAt: $0.placedAt, id: $0.id, than: $1.placedAt, id: $1.id)
        }

        var built: [Entry] = []
        built.reserveCapacity(sorted.count)
        var newerStart: Date?
        for record in sorted {
            // Stamped stops are clamped to the start; missing stops on
            // non-newest records (legacy data, anomalies) are inferred from
            // the next placement's start.
            let stop = record.removedAt.map { max($0, record.placedAt) } ?? newerStart
            built.append(Entry(
                record: record,
                siteID: SiteID.canonical(record.siteID),
                placedAt: record.placedAt,
                stop: stop
            ))
            newerStart = record.placedAt
        }

        entries = built
        current = built.first?.stop == nil ? built.first : nil
        lastUsedBySite = Dictionary(
            grouping: built, by: \.siteID
        ).compactMapValues { $0.map(\.placedAt).max() }
    }

    /// Mean wear across completed placements; nil until one has finished.
    var averageWear: TimeInterval? {
        let wears = entries.compactMap(\.wear)
        guard !wears.isEmpty else { return nil }
        return wears.reduce(0, +) / Double(wears.count)
    }

    /// Entries from every track, each with its stop resolved *within its own
    /// track*, merged newest-first for the shared history list. Building one
    /// merged timeline instead would infer an open placement's stop from the
    /// next record in either track — so a device still on would look removed
    /// the moment the other track got a newer placement. Per-track resolution
    /// keeps every currently-worn device open.
    static func combinedEntries(records: [PlacementRecord]) -> [Entry] {
        // Group by resolved track — an unknown/legacy deviceType buckets to
        // .pump, matching Entry.deviceType — so no record is dropped, and
        // resolve stops within each track.
        Dictionary(grouping: records) { DeviceType(rawValue: $0.deviceType) ?? .pump }
            .values
            .flatMap { PlacementTimeline(records: $0).entries }
            .sorted { isNewer(placedAt: $0.placedAt, id: $0.id, than: $1.placedAt, id: $1.id) }
    }

    /// Newest-first ordering: later placement first; ties broken by descending
    /// id so the order is stable and total.
    private static func isNewer(placedAt a: Date, id aID: UUID, than b: Date, id bID: UUID) -> Bool {
        a == b ? aID.uuidString > bID.uuidString : a > b
    }
}

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

// MARK: - Editing a record's times

extension PlacementTimeline {
    /// What a single record's "on" and "off" times are allowed to be, derived
    /// from its neighbours in the same track.
    ///
    /// Editing times after the fact must not reorder history: a placement can
    /// slide anywhere between the placements either side of it, but never past
    /// them. One type owns those limits so the pickers that offer the range and
    /// the store that validates the write can't drift apart.
    struct TimingBounds {
        /// The record's stored start, used as the reference point when there is
        /// no older placement to bound against.
        let currentPlacedAt: Date
        /// Start of the older placement in this track, if any.
        let previousPlacedAt: Date?
        /// Start of the newer placement in this track, if any.
        let nextPlacedAt: Date?
        /// Captured once so the pickers and the validator agree on "now".
        let now: Date

        /// Placements keep a minute of daylight between them: the pickers work
        /// in minutes, so touching timestamps would let two records land on the
        /// same instant and leave the ordering to the UUID tie-break.
        static let gap: TimeInterval = 60
        /// How far back an unbounded start may reach — a decade is past any
        /// plausible journal without handing the wheel `Date.distantPast`.
        private static let floor: TimeInterval = 10 * 365 * 24 * 3600

        /// When the placement may have started.
        var placedAtRange: ClosedRange<Date> {
            let lower = previousPlacedAt?.addingTimeInterval(Self.gap)
                ?? currentPlacedAt.addingTimeInterval(-Self.floor)
            // No newer placement means this is the current one: it can't have
            // started in the future.
            let upper = nextPlacedAt?.addingTimeInterval(-Self.gap)
                ?? max(now, currentPlacedAt)
            return lower...max(lower, upper)
        }

        /// When the placement may have stopped, given the start on screen — so
        /// the stop wheel tracks the start as the user drags it.
        ///
        /// A stop may land exactly on the next placement's start: that is what
        /// `JournalStore.startPlacement` stamps when it closes the previous
        /// record, so the boundary has to stay reachable.
        func removedAtRange(placedAt: Date) -> ClosedRange<Date> {
            let upper = nextPlacedAt ?? max(now, placedAt)
            return placedAt...max(placedAt, upper)
        }
    }

    /// Bounds for one record. A record this timeline doesn't hold (a track
    /// mismatch, or one just deleted) falls back to "anything up to now".
    func timingBounds(for record: PlacementRecord, now: Date = .now) -> TimingBounds {
        guard let index = entries.firstIndex(where: { $0.record.id == record.id }) else {
            return TimingBounds(
                currentPlacedAt: record.placedAt,
                previousPlacedAt: nil,
                nextPlacedAt: nil,
                now: now
            )
        }
        // `entries` is newest-first, so the newer neighbour is the lower index.
        return TimingBounds(
            currentPlacedAt: record.placedAt,
            previousPlacedAt: entries.indices.contains(index + 1) ? entries[index + 1].placedAt : nil,
            nextPlacedAt: index > 0 ? entries[index - 1].placedAt : nil,
            now: now
        )
    }
}

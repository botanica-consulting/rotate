import Foundation
import SwiftData

/// The one place that mutates placement history. Every operation either
/// commits fully or rolls the context back and throws — callers surface the
/// error instead of pretending the write happened.
@MainActor
struct JournalStore {
    let context: ModelContext

    /// All records, newest first.
    func history() throws -> [PlacementRecord] {
        try context.fetch(FetchDescriptor<PlacementRecord>(
            sortBy: [SortDescriptor(\.placedAt, order: .reverse)]
        ))
    }

    /// Atomically starts a new placement for one device track: every open
    /// record of that same device is closed at the new start (never before its
    /// own start), then the new record begins. Enforces "at most one open
    /// placement per device" and `removedAt >= placedAt`. Placing a sensor
    /// never closes an open Pod, and vice-versa.
    @discardableResult
    func startPlacement(
        siteID: String,
        deviceType: DeviceType = .pump,
        at now: Date = .now
    ) throws -> PlacementRecord {
        let open = try openRecords(deviceType: deviceType)
        for record in open {
            record.removedAt = max(now, record.placedAt)
        }
        let record = PlacementRecord(siteID: siteID, placedAt: now, deviceType: deviceType.rawValue)
        context.insert(record)
        try saveOrRollback()
        return record
    }

    /// Deletes one record. Deletion never reopens another Pod — a removal
    /// time, once written, is history.
    func delete(_ record: PlacementRecord) throws {
        context.delete(record)
        try saveOrRollback()
    }

    /// Deletes the entire journal. Instance-by-instance (not the batch API)
    /// so `@Query` views observe the change immediately.
    func reset() throws {
        for record in try context.fetch(FetchDescriptor<PlacementRecord>()) {
            context.delete(record)
        }
        try saveOrRollback()
    }

    /// Persists in-place edits (notes, times) made through bindings.
    func save() throws {
        try saveOrRollback()
    }

    // MARK: - Custom sites

    /// The user's own sites, oldest first — the order the mirror and every
    /// site-ID list keeps.
    func customSites(includingArchived: Bool = false) throws -> [CustomSite] {
        let all = try context.fetch(FetchDescriptor<CustomSite>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        ))
        return includingArchived ? all : all.filter { !$0.isArchived }
    }

    @discardableResult
    func addCustomSite(name: String) throws -> CustomSite {
        let site = CustomSite(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(site)
        try saveOrRollback()
        return site
    }

    func rename(_ site: CustomSite, to name: String) throws {
        site.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try saveOrRollback()
    }

    /// Archiving is the delete: the record keeps existing so placements on it
    /// still resolve to a name instead of a raw ID.
    func setArchived(_ site: CustomSite, _ isArchived: Bool) throws {
        site.isArchived = isArchived
        try saveOrRollback()
    }

    /// Rewrites one record's start and stop after the fact — the only edit
    /// path for times. Re-checks the same bounds the pickers offer, so a stale
    /// sheet (or a record the other device moved meanwhile) can't reorder
    /// history, and rolls back rather than storing something the timeline would
    /// have to repair on every read.
    ///
    /// A value left untouched always passes, so saving an unedited sheet can
    /// never fail on pre-invariant data that already sits outside the range.
    func updateTiming(_ record: PlacementRecord, placedAt: Date, removedAt: Date?) throws {
        let device = DeviceType(rawValue: record.deviceType) ?? .pump
        let timeline = PlacementTimeline(records: try history(), deviceType: device)
        let bounds = timeline.timingBounds(for: record)

        if placedAt != record.placedAt {
            guard bounds.placedAtRange.contains(placedAt) else {
                throw TimingError.startOutOfRange
            }
        }
        if let removedAt {
            guard removedAt >= placedAt else { throw TimingError.stopBeforeStart }
            if removedAt != record.removedAt {
                guard bounds.removedAtRange(placedAt: placedAt).contains(removedAt) else {
                    throw TimingError.stopOutOfRange
                }
            }
        } else if record.removedAt != nil {
            // Clearing a stop reopens this placement — only allowed when no
            // other record on the track is already open.
            let others = try openRecords(deviceType: device).filter { $0.id != record.id }
            guard others.isEmpty else { throw TimingError.wouldOpenSecondPlacement }
        }

        record.placedAt = placedAt
        record.removedAt = removedAt
        try saveOrRollback()
    }

    /// Why a timing edit was refused, worded for the alert the sheet shows.
    enum TimingError: LocalizedError, Equatable {
        case startOutOfRange
        case stopBeforeStart
        case stopOutOfRange
        case wouldOpenSecondPlacement

        var errorDescription: String? {
            switch self {
            case .startOutOfRange:
                "That start time would move this placement past the one before or after it."
            case .stopBeforeStart:
                "A placement can't come off before it went on."
            case .stopOutOfRange:
                "That removal time would overlap the next placement."
            case .wouldOpenSecondPlacement:
                "Another placement on this track is still on, so this one can't be reopened."
            }
        }
    }

    private func openRecords(deviceType: DeviceType) throws -> [PlacementRecord] {
        let raw = deviceType.rawValue
        return try context.fetch(FetchDescriptor<PlacementRecord>(
            predicate: #Predicate { $0.removedAt == nil && $0.deviceType == raw }
        ))
    }

    private func saveOrRollback() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

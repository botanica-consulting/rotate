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

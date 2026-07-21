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

    /// Atomically starts a new placement: every open record is closed at the
    /// new start (never before its own start), then the new record begins.
    /// Enforces "at most one open placement" and `removedAt >= placedAt`.
    @discardableResult
    func startPlacement(siteID: String, at now: Date = .now) throws -> PlacementRecord {
        let open = try openRecords()
        for record in open {
            record.removedAt = max(now, record.placedAt)
        }
        let record = PlacementRecord(siteID: siteID, placedAt: now)
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

    private func openRecords() throws -> [PlacementRecord] {
        try context.fetch(FetchDescriptor<PlacementRecord>(
            predicate: #Predicate { $0.removedAt == nil }
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

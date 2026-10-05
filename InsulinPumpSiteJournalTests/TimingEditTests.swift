import Foundation
import SwiftData
import Testing
@testable import InsulinPumpSiteJournal

/// Editing a placement's times after the fact. The pickers only offer the gap
/// between neighbouring placements; `JournalStore.updateTiming` is the backstop
/// that keeps a stale sheet from reordering history.
@MainActor
struct TimingEditTests {
    private func store() throws -> (JournalStore, ModelContext) {
        let container = try ModelContainer(
            for: PlacementRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        return (JournalStore(context: context), context)
    }

    /// Three pump placements a day apart, newest last in the returned array.
    private func threeDays(in context: ModelContext) throws -> [PlacementRecord] {
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        var made: [PlacementRecord] = []
        for day in 0..<3 {
            let placedAt = base.addingTimeInterval(Double(day) * 86_400)
            let record = PlacementRecord(
                siteID: PumpSite.catalog[day].id,
                placedAt: placedAt,
                removedAt: day == 2 ? nil : placedAt.addingTimeInterval(86_400)
            )
            context.insert(record)
            made.append(record)
        }
        try context.save()
        return made
    }

    @Test func boundsAreTheGapBetweenNeighbours() throws {
        let (_, context) = try store()
        let records = try threeDays(in: context)
        let timeline = PlacementTimeline(records: records, deviceType: .pump)

        let middle = timeline.timingBounds(for: records[1])
        #expect(middle.previousPlacedAt == records[0].placedAt)
        #expect(middle.nextPlacedAt == records[2].placedAt)
        // A minute of daylight either side, so two records never share an instant.
        let gap = PlacementTimeline.TimingBounds.gap
        #expect(middle.placedAtRange.lowerBound == records[0].placedAt.addingTimeInterval(gap))
        #expect(middle.placedAtRange.upperBound == records[2].placedAt.addingTimeInterval(-gap))
    }

    @Test func newestPlacementCannotStartInTheFuture() throws {
        let (_, context) = try store()
        let records = try threeDays(in: context)
        let now = records[2].placedAt.addingTimeInterval(7_200)
        let bounds = PlacementTimeline(records: records, deviceType: .pump)
            .timingBounds(for: records[2], now: now)

        #expect(bounds.nextPlacedAt == nil)
        #expect(bounds.placedAtRange.upperBound == now)
    }

    @Test func stopMayLandExactlyOnTheNextPlacement() throws {
        let (_, context) = try store()
        let records = try threeDays(in: context)
        let bounds = PlacementTimeline(records: records, deviceType: .pump)
            .timingBounds(for: records[1])

        // That boundary is what startPlacement stamps when it closes a record,
        // so it has to stay reachable.
        let range = bounds.removedAtRange(placedAt: records[1].placedAt)
        #expect(range.contains(records[2].placedAt))
        #expect(range.lowerBound == records[1].placedAt)
    }

    @Test func rangesNeverInvertWhenNeighboursAreClose() throws {
        let (_, context) = try store()
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        // Two placements ten seconds apart — closer than the one-minute gap.
        let older = PlacementRecord(siteID: "abdomen-left", placedAt: base)
        let newer = PlacementRecord(siteID: "abdomen-right", placedAt: base.addingTimeInterval(10))
        context.insert(older)
        context.insert(newer)
        try context.save()

        let bounds = PlacementTimeline(records: [older, newer], deviceType: .pump)
            .timingBounds(for: newer)
        // A ClosedRange traps on an inverted bound; the clamp keeps it valid.
        #expect(bounds.placedAtRange.lowerBound <= bounds.placedAtRange.upperBound)
        #expect(bounds.removedAtRange(placedAt: newer.placedAt).lowerBound <= bounds.removedAtRange(placedAt: newer.placedAt).upperBound)
    }

    @Test func editingWithinTheGapIsStored() throws {
        let (journal, context) = try store()
        let records = try threeDays(in: context)
        let moved = records[1].placedAt.addingTimeInterval(3_600)

        try journal.updateTiming(records[1], placedAt: moved, removedAt: records[1].removedAt)

        #expect(records[1].placedAt == moved)
        let reread = try journal.history()
        #expect(reread.map(\.placedAt) == reread.map(\.placedAt).sorted(by: >))
    }

    @Test func startPastTheNextPlacementIsRefused() throws {
        let (journal, context) = try store()
        let records = try threeDays(in: context)
        let original = records[1].placedAt

        #expect(throws: JournalStore.TimingError.startOutOfRange) {
            try journal.updateTiming(
                records[1],
                placedAt: records[2].placedAt.addingTimeInterval(3_600),
                removedAt: records[1].removedAt
            )
        }
        // Refused edits leave the record exactly as it was.
        #expect(records[1].placedAt == original)
    }

    @Test func stopBeforeStartIsRefused() throws {
        let (journal, context) = try store()
        let records = try threeDays(in: context)

        #expect(throws: JournalStore.TimingError.stopBeforeStart) {
            try journal.updateTiming(
                records[1],
                placedAt: records[1].placedAt,
                removedAt: records[1].placedAt.addingTimeInterval(-60)
            )
        }
    }

    @Test func stopOverlappingTheNextPlacementIsRefused() throws {
        let (journal, context) = try store()
        let records = try threeDays(in: context)

        #expect(throws: JournalStore.TimingError.stopOutOfRange) {
            try journal.updateTiming(
                records[1],
                placedAt: records[1].placedAt,
                removedAt: records[2].placedAt.addingTimeInterval(60)
            )
        }
    }

    @Test func reopeningIsRefusedWhileAnotherPlacementIsOn() throws {
        let (journal, context) = try store()
        let records = try threeDays(in: context)
        // records[2] is already open, so records[1] can't also be reopened.

        #expect(throws: JournalStore.TimingError.wouldOpenSecondPlacement) {
            try journal.updateTiming(records[1], placedAt: records[1].placedAt, removedAt: nil)
        }
    }

    @Test func newestPlacementCanBeReopened() throws {
        let (journal, context) = try store()
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        let record = PlacementRecord(
            siteID: "abdomen-left",
            placedAt: base,
            removedAt: base.addingTimeInterval(3_600)
        )
        context.insert(record)
        try context.save()

        try journal.updateTiming(record, placedAt: base, removedAt: nil)
        #expect(record.removedAt == nil)
        #expect(PlacementTimeline(records: [record], deviceType: .pump).current != nil)
    }

    @Test func savingAnUnchangedSheetAlwaysSucceeds() throws {
        let (journal, context) = try store()
        // Pre-invariant data: two records sharing an instant, which the current
        // bounds would never allow a *new* edit to produce.
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        let older = PlacementRecord(siteID: "abdomen-left", placedAt: base, removedAt: base)
        let newer = PlacementRecord(siteID: "abdomen-right", placedAt: base, removedAt: nil)
        context.insert(older)
        context.insert(newer)
        try context.save()

        // Closing the sheet without touching the wheels must not fail.
        try journal.updateTiming(older, placedAt: older.placedAt, removedAt: older.removedAt)
        #expect(older.placedAt == base)
    }

    @Test func editsOnOneTrackIgnoreTheOther() throws {
        let (journal, context) = try store()
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        let pump = PlacementRecord(
            siteID: "abdomen-left",
            placedAt: base,
            removedAt: base.addingTimeInterval(86_400),
            deviceType: DeviceType.pump.rawValue
        )
        // A sensor placement in the middle of the pump's wear must not bound it.
        let sensor = PlacementRecord(
            siteID: "back-upper-arm-left",
            placedAt: base.addingTimeInterval(3_600),
            deviceType: DeviceType.cgm.rawValue
        )
        context.insert(pump)
        context.insert(sensor)
        try context.save()

        let moved = base.addingTimeInterval(7_200)
        try journal.updateTiming(pump, placedAt: moved, removedAt: pump.removedAt)
        #expect(pump.placedAt == moved)
    }
}

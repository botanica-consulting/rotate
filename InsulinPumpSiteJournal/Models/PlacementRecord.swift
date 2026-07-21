import Foundation
import SwiftData

// CloudKit-compatible model: no `@Attribute(.unique)` (CloudKit forbids unique
// constraints) and every property carries a default value. Do not add either
// back — it would block enabling iCloud sync later.
@Model
final class PlacementRecord {
    var id: UUID = UUID()
    var siteID: String = ""
    var placedAt: Date = Date.now
    /// When the Pod came off. Stamped when the next Pod is saved; nil while
    /// this is the current Pod (and on records from before stop tracking —
    /// display code infers those from the next placement).
    var removedAt: Date?
    /// Free-form journal notes for this wear ("leaked", "fell off", …).
    var notes: String = ""

    init(
        id: UUID = UUID(),
        siteID: String,
        placedAt: Date = .now,
        removedAt: Date? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.siteID = siteID
        self.placedAt = placedAt
        self.removedAt = removedAt
        self.notes = notes
    }
}

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

    init(
        id: UUID = UUID(),
        siteID: String,
        placedAt: Date = .now
    ) {
        self.id = id
        self.siteID = siteID
        self.placedAt = placedAt
    }
}

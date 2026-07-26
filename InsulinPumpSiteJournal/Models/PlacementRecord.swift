import Foundation
import SwiftData

// CloudKit-compatible model: no `@Attribute(.unique)` (CloudKit forbids unique
// constraints) and every property carries a default value. Do not add either
// back — it would block enabling iCloud sync later.
//
// Adding or renaming a property here also needs a CloudKit Production schema
// deploy before the build ships — see `storeConfiguration()` in
// InsulinPumpSiteJournalApp.swift for the procedure.
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
    /// Which rotation track this belongs to (`DeviceType` raw value). Defaults
    /// to "pump" so existing records migrate cleanly (lightweight backfill) and
    /// the CloudKit-compat rule — every property has a default — is preserved.
    var deviceType: String = DeviceType.pump.rawValue

    init(
        id: UUID = UUID(),
        siteID: String,
        placedAt: Date = .now,
        removedAt: Date? = nil,
        notes: String = "",
        deviceType: String = DeviceType.pump.rawValue
    ) {
        self.id = id
        self.siteID = siteID
        self.placedAt = placedAt
        self.removedAt = removedAt
        self.notes = notes
        self.deviceType = deviceType
    }
}

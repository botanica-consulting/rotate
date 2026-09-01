import Foundation
import SwiftData

/// A site the user added themselves, for a spot the body figure doesn't cover.
///
/// Belongs to one track. A pump site and a sensor site are different places
/// chosen for different reasons, so the two lists are kept apart the same way
/// the two histories are — each track's screen manages only its own.
///
/// Custom sites get no artwork of their own — we can't know where on the body
/// the user means — so they render as a free-floating area shape (see
/// `CustomSiteThumbnail`).
///
/// CloudKit-compatible model, same rules as `PlacementRecord`: no
/// `@Attribute(.unique)` and every property carries a default. Being a *new*
/// record type, it also needs a CloudKit Production schema deploy before the
/// build ships — see `storeConfiguration()` in InsulinPumpSiteJournalApp.swift.
@Model
final class CustomSite {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now
    /// Soft delete. Removing a custom site outright would turn its history rows
    /// into raw "custom-<uuid>" labels, so the name stays resolvable while the
    /// site drops out of suggestions, the picker, and the body map.
    var isArchived: Bool = false
    /// The track this site belongs to. Stored raw for CloudKit, which has no
    /// enum type — same treatment as `PlacementRecord.deviceType`.
    var deviceType: String = DeviceType.pump.rawValue

    init(
        id: UUID = UUID(),
        name: String = "",
        createdAt: Date = .now,
        isArchived: Bool = false,
        device: DeviceType = .pump
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.deviceType = device.rawValue
    }

    var device: DeviceType { DeviceType(rawValue: deviceType) ?? .pump }

    /// The `PlacementRecord.siteID` that points at this site.
    var siteID: String { SiteID.custom(id) }
}

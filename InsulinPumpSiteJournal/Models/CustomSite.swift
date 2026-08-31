import Foundation
import SwiftData

/// A site the user added themselves, for a spot the body figure doesn't cover.
///
/// Custom sites get no artwork of their own — we can't know where on the body
/// the user means, and letting them draw an area is a much bigger feature — so
/// they render as a free-floating area shape with no body under it (see
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

    init(
        id: UUID = UUID(),
        name: String = "",
        createdAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isArchived = isArchived
    }

    /// The `PlacementRecord.siteID` that points at this site.
    var siteID: String { SiteID.custom(id) }
}

import Foundation

/// Canonical spelling of stored site IDs.
///
/// History written before the region remodel used quadrant-style IDs
/// ("abdomen-upper-left"). Every consumer — display, recency tiers, and the
/// suggestion engine — must agree on one spelling, or an old placement stops
/// counting toward rotation safety. Canonicalize at this single boundary
/// whenever a stored ID enters domain logic.
enum SiteID {
    nonisolated static func canonical(_ raw: String) -> String {
        legacyMap[raw] ?? raw
    }

    /// Prefix marking a user-added site, so a stored ID says which catalog it
    /// belongs to without a lookup. Custom IDs carry no legacy spelling, and
    /// `canonical` passes them through untouched.
    nonisolated static let customPrefix = "custom-"

    /// The stored ID for a `CustomSite`.
    nonisolated static func custom(_ id: UUID) -> String {
        customPrefix + id.uuidString
    }

    nonisolated static func isCustom(_ raw: String) -> Bool {
        raw.hasPrefix(customPrefix)
    }

    /// The `CustomSite` identity behind a stored ID, if it is a custom one.
    nonisolated static func customUUID(_ raw: String) -> UUID? {
        guard isCustom(raw) else { return nil }
        return UUID(uuidString: String(raw.dropFirst(customPrefix.count)))
    }

    /// Pre-remodel IDs mapped onto the nearest current site.
    nonisolated private static let legacyMap: [String: String] = [
        "abdomen-upper-left": "abdomen-left",
        "abdomen-lower-left": "abdomen-left",
        "abdomen-upper-right": "abdomen-right",
        "abdomen-lower-right": "abdomen-right",
        "thigh-left": "front-thigh-left",
        "thigh-right": "front-thigh-right",
        "arm-upper-left": "back-upper-arm-left",
        "arm-upper-right": "back-upper-arm-right",
        "buttock-upper-left": "upper-buttock-left",
        "buttock-upper-right": "upper-buttock-right",
    ]
}

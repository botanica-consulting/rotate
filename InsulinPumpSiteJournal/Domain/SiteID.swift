import Foundation

/// Canonical spelling of stored site IDs.
///
/// History written before the region remodel used quadrant-style IDs
/// ("abdomen-upper-left"). Every consumer — display, recency tiers, and the
/// suggestion engine — must agree on one spelling, or an old placement stops
/// counting toward rotation safety. Canonicalize at this single boundary
/// whenever a stored ID enters domain logic.
enum SiteID {
    static func canonical(_ raw: String) -> String {
        legacyMap[raw] ?? raw
    }

    /// Pre-remodel IDs mapped onto the nearest current site.
    private static let legacyMap: [String: String] = [
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

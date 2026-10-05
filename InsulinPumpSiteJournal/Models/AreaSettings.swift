import Foundation

/// Which individual mounting sites a device track rotates through. Stored per
/// track as a comma-joined list of *disabled* site IDs, so the default (an
/// empty or absent value) means every site is enabled — the full body catalog
/// is on by default for both the pump and the sensor. `PumpSite.sites(for:)`
/// and the body map read this so an excluded site is never suggested or shown
/// for that track. Excluding is per-area (not per-region), so a track can drop
/// just one arm or one thigh without losing the other.
enum AreaSettings {
    static func storageKey(for device: DeviceType) -> String {
        "disabledSites-\(device.rawValue)"
    }

    /// `defaults` is injectable for the same reason `CustomSiteStore`'s is:
    /// these are global reads, and a test that has to see the unfiltered
    /// catalog can't be at the mercy of whatever a UI test left behind in the
    /// simulator's real defaults.
    static func disabledSites(for device: DeviceType, defaults: UserDefaults = .standard) -> Set<String> {
        parse(defaults.string(forKey: storageKey(for: device)))
    }

    /// Decodes the stored string into a site-ID set. IDs are kept verbatim;
    /// unknown ones simply never match a catalog site.
    static func parse(_ raw: String?) -> Set<String> {
        guard let raw, !raw.isEmpty else { return [] }
        return Set(raw.split(separator: ",").map(String.init))
    }

    /// Encodes in a stable catalog order so the persisted string doesn't churn.
    ///
    /// The order spans the built-in catalog *and* the user's own sites: filtering
    /// against `PumpSite.catalog` alone would silently drop a custom site's
    /// exclusion on the next write.
    static func encode(_ ids: Set<String>, defaults: UserDefaults = .standard) -> String {
        let order = PumpSite.catalog.map(\.id) + CustomSiteStore.allSiteIDs(defaults: defaults)
        return order.filter(ids.contains).joined(separator: ",")
    }
}

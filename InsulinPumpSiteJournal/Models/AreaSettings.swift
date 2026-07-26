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

    static func disabledSites(for device: DeviceType) -> Set<String> {
        parse(UserDefaults.standard.string(forKey: storageKey(for: device)))
    }

    /// Decodes the stored string into a site-ID set. IDs are kept verbatim;
    /// unknown ones simply never match a catalog site.
    static func parse(_ raw: String?) -> Set<String> {
        guard let raw, !raw.isEmpty else { return [] }
        return Set(raw.split(separator: ",").map(String.init))
    }

    /// Encodes in a stable catalog order so the persisted string doesn't churn.
    static func encode(_ ids: Set<String>) -> String {
        PumpSite.catalog.map(\.id).filter(ids.contains).joined(separator: ",")
    }
}

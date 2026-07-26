import Foundation

/// Which mounting regions a device track rotates through. Stored per track as a
/// comma-joined list of *disabled* region raw values, so the default (an empty
/// or absent value) means every region is enabled — the full set is on by
/// default for both the pump and the sensor. `PumpSite.sites(for:)` and the
/// body map read this so an excluded region is never suggested or shown for
/// that track.
enum RegionSettings {
    static func storageKey(for device: DeviceType) -> String {
        "disabledRegions-\(device.rawValue)"
    }

    static func disabledRegions(for device: DeviceType) -> Set<PumpSite.Region> {
        parse(UserDefaults.standard.string(forKey: storageKey(for: device)))
    }

    /// Decodes the stored string into a region set (unknown values ignored).
    static func parse(_ raw: String?) -> Set<PumpSite.Region> {
        guard let raw, !raw.isEmpty else { return [] }
        return Set(raw.split(separator: ",").compactMap { PumpSite.Region(rawValue: String($0)) })
    }

    /// Encodes in a stable catalog order so the persisted string doesn't churn.
    static func encode(_ regions: Set<PumpSite.Region>) -> String {
        PumpSite.Region.allCases.filter(regions.contains).map(\.rawValue).joined(separator: ",")
    }
}

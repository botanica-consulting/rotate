import Foundation

/// The read cache for custom sites, one list per track.
///
/// `CustomSite` lives in SwiftData so it syncs, but the site catalog is read
/// from static entry points that hold no model context — `PumpSite.sites(for:)`
/// and `PumpSite.site(for:)` are called from shapes, thumbnails, and the
/// suggestion engine. Rather than thread a context through all of them, this
/// mirrors the sites into `UserDefaults` exactly as `AreaSettings` already
/// stores its per-track exclusions, under one key per track.
///
/// SwiftData stays the source of truth; the mirror is refreshed from the live
/// `@Query` in `HistoryHomeView`, which also fires when CloudKit merges a
/// change made on another device.
enum CustomSiteStore {
    static func storageKey(for device: DeviceType) -> String { "customSites-\(device.rawValue)" }

    /// One mirrored site. Archived ones stay in the mirror so a history row on
    /// an archived site still shows its name instead of a raw ID.
    struct Entry: Codable, Hashable, Identifiable {
        var id: String
        var name: String
        var isArchived: Bool
    }

    // MARK: Writing the mirror

    /// Takes every site, not one track's, and rewrites both keys — a track that
    /// just lost its last site has to end up empty rather than stale.
    static func refreshMirror(_ sites: [CustomSite], defaults: UserDefaults = .standard) {
        for device in DeviceType.allCases {
            let entries = sites
                .filter { $0.device == device }
                .sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt }
                .map { Entry(id: $0.siteID, name: $0.name, isArchived: $0.isArchived) }
            write(entries, for: device, defaults: defaults)
        }
    }

    static func write(_ entries: [Entry], for device: DeviceType, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey(for: device))
    }

    // MARK: Reading

    static func entries(for device: DeviceType, defaults: UserDefaults = .standard) -> [Entry] {
        guard let data = defaults.data(forKey: storageKey(for: device)),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return decoded
    }

    /// Sites offered for new placements on a track — archived ones excluded.
    static func activeSites(for device: DeviceType, defaults: UserDefaults = .standard) -> [PumpSite] {
        entries(for: device, defaults: defaults)
            .filter { !$0.isArchived }
            .map { PumpSite.custom(id: $0.id, name: $0.name) }
    }

    /// Any custom site by ID, archived and either track included: a history row
    /// has to keep its label whichever list the site came from.
    static func site(for id: String, defaults: UserDefaults = .standard) -> PumpSite? {
        guard SiteID.isCustom(id) else { return nil }
        for device in DeviceType.allCases {
            if let entry = entries(for: device, defaults: defaults).first(where: { $0.id == id }) {
                return PumpSite.custom(id: entry.id, name: entry.name)
            }
        }
        return nil
    }

    /// Stable ID order for anything that persists a set of site IDs
    /// (see `AreaSettings.encode`). Spans both tracks: the order only has to be
    /// stable, and an ID from the other track costs nothing to carry.
    static func allSiteIDs(defaults: UserDefaults = .standard) -> [String] {
        DeviceType.allCases.flatMap { entries(for: $0, defaults: defaults).map(\.id) }
    }
}

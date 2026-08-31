import Foundation

/// The read cache for custom sites.
///
/// `CustomSite` lives in SwiftData so it syncs, but the site catalog is read
/// from static entry points that hold no model context — `PumpSite.sites(for:)`
/// and `PumpSite.site(for:)` are called from shapes, thumbnails, and the
/// suggestion engine. Rather than thread a context through all of them, this
/// mirrors the sites into `UserDefaults` exactly as `AreaSettings` already
/// stores its per-track exclusions.
///
/// SwiftData stays the source of truth; the mirror is refreshed from the live
/// `@Query` in `HistoryHomeView`, which also fires when CloudKit merges a
/// change made on another device.
enum CustomSiteStore {
    static let storageKey = "customSites"

    /// One mirrored site. Archived ones stay in the mirror so a history row on
    /// an archived site still shows its name instead of a raw ID.
    struct Entry: Codable, Hashable, Identifiable {
        var id: String
        var name: String
        var isArchived: Bool
    }

    // MARK: Writing the mirror

    static func refreshMirror(_ sites: [CustomSite], defaults: UserDefaults = .standard) {
        let entries = sites
            .sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt }
            .map { Entry(id: $0.siteID, name: $0.name, isArchived: $0.isArchived) }
        write(entries, defaults: defaults)
    }

    static func write(_ entries: [Entry], defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey)
    }

    // MARK: Reading

    static func entries(defaults: UserDefaults = .standard) -> [Entry] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return decoded
    }

    /// Sites offered for new placements — archived ones are excluded.
    static func activeSites(defaults: UserDefaults = .standard) -> [PumpSite] {
        entries(defaults: defaults)
            .filter { !$0.isArchived }
            .map { PumpSite.custom(id: $0.id, name: $0.name) }
    }

    /// Any custom site by ID, archived included, so history keeps its label.
    static func site(for id: String, defaults: UserDefaults = .standard) -> PumpSite? {
        guard SiteID.isCustom(id) else { return nil }
        guard let entry = entries(defaults: defaults).first(where: { $0.id == id }) else { return nil }
        return PumpSite.custom(id: entry.id, name: entry.name)
    }

    /// Stable ID order for anything that persists a set of site IDs
    /// (see `AreaSettings.encode`).
    static func allSiteIDs(defaults: UserDefaults = .standard) -> [String] {
        entries(defaults: defaults).map(\.id)
    }
}

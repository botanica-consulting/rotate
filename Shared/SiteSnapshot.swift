import Foundation

/// What's on the body right now, small enough to live in shared defaults.
///
/// Only the start date and the site's name — the widget derives the hour count
/// from `placedAt` in its own timeline, so the number stays right between
/// writes and the app doesn't have to wake up to keep it current.
nonisolated struct SiteSnapshot: Codable, Equatable {
    nonisolated struct Track: Codable, Equatable {
        var placedAt: Date
        var siteTitle: String
    }

    var pump: Track?
    var cgm: Track?

    nonisolated static let storageKey = "siteSnapshot"

    nonisolated func track(for device: DeviceType) -> Track? {
        switch device {
        case .pump: pump
        case .cgm: cgm
        }
    }

    nonisolated mutating func setTrack(_ track: Track?, for device: DeviceType) {
        switch device {
        case .pump: pump = track
        case .cgm: cgm = track
        }
    }

    nonisolated static func load(from defaults: UserDefaults = AppGroup.defaults) -> SiteSnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(SiteSnapshot.self, from: data)
        else { return SiteSnapshot() }
        return decoded
    }

    nonisolated static func save(_ snapshot: SiteSnapshot, to defaults: UserDefaults = AppGroup.defaults) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

import Foundation

/// Classifies sites into recency tiers by how recently they were last used,
/// ranked most-recent-first across the sites that appear in history:
/// ranks 0–2 are `veryRecent` (red), 3–5 `recent` (orange), 6–8
/// `relativelyRecent` (yellow), and everything older — or never used — is
/// `base` (clear). Deterministic and time-scale-free.
struct SiteRecencyModel {
    enum Tier {
        case base
        case relativelyRecent
        case recent
        case veryRecent
    }

    private let rankBySite: [String: Int]

    init(history: [PlacementRecord]) {
        let lastUsedBySite = Dictionary(grouping: history, by: \.siteID)
            .compactMapValues { $0.map(\.placedAt).max() }
        let ranked = lastUsedBySite.sorted { a, b in
            a.value == b.value ? a.key < b.key : a.value > b.value
        }
        rankBySite = Dictionary(
            uniqueKeysWithValues: ranked.enumerated().map { ($0.element.key, $0.offset) }
        )
    }

    func tier(for siteID: String) -> Tier {
        guard let rank = rankBySite[siteID] else { return .base }
        switch rank {
        case 0...2: return .veryRecent
        case 3...5: return .recent
        case 6...8: return .relativelyRecent
        default: return .base
        }
    }

    /// The last three used sites — never offered as suggestions.
    var veryRecentSiteIDs: Set<String> {
        Set(rankBySite.filter { $0.value <= 2 }.keys)
    }
}

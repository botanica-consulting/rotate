import Foundation

/// Deterministic least-recently-used site picker.
///
/// Never-used sites come first (in catalog order), then used sites by oldest
/// use date. The immediately previous site is excluded. Results favor region
/// diversity: a first pass picks sites from distinct regions, a second pass
/// fills any remaining slots from the sorted candidates.
struct SiteSuggestionEngine {
    func suggestions(
        from sites: [PumpSite],
        history: [PlacementRecord],
        limit: Int = 4,
        excluding: Set<String> = []
    ) -> [PumpSite] {
        guard !history.isEmpty else {
            let starters = PumpSite.starterSiteIDs
                .compactMap { id in sites.first { $0.id == id && !excluding.contains(id) } }
            if starters.count >= limit {
                return Array(starters.prefix(limit))
            }
            // Excluded starters (e.g. after a shuffle) are replaced from the
            // remaining catalog, keeping region diversity via the main path.
            var result = starters
            for site in sites where result.count < limit {
                if !excluding.contains(site.id), !result.contains(site) {
                    result.append(site)
                }
            }
            return result
        }

        // Group by canonical ID so pre-remodel records keep counting toward
        // rotation safety (a legacy abdomen record must age the abdomen).
        let lastUsedBySite = Dictionary(
            grouping: history,
            by: { SiteID.canonical($0.siteID) }
        ).mapValues { records in
            records.map(\.placedAt).max()!
        }

        let previousSiteID = SiteID.canonical(history.max { $0.placedAt < $1.placedAt }!.siteID)

        // `sites` is catalog-ordered; the enumeration offset is the stable tie-breaker.
        let candidates = sites.enumerated()
            .filter { $0.element.id != previousSiteID && !excluding.contains($0.element.id) }
            .sorted { a, b in
                switch (lastUsedBySite[a.element.id], lastUsedBySite[b.element.id]) {
                case (nil, nil):
                    return a.offset < b.offset
                case (nil, _):
                    return true
                case (_, nil):
                    return false
                case let (dateA?, dateB?):
                    return dateA == dateB ? a.offset < b.offset : dateA < dateB
                }
            }
            .map(\.element)

        var result: [PumpSite] = []
        var usedRegions: Set<PumpSite.Region> = []

        for site in candidates where result.count < limit {
            if !usedRegions.contains(site.region) {
                result.append(site)
                usedRegions.insert(site.region)
            }
        }
        for site in candidates where result.count < limit {
            if !result.contains(site) {
                result.append(site)
            }
        }
        return result
    }
}

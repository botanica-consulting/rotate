import SwiftUI

/// The tier-to-color mapping, kept out of `AppTheme` itself so the palette has
/// no dependency on the recency model — that lets the widget extension compile
/// `AppTheme` for the track tints without dragging the SwiftData layer in.
extension AppTheme {
    /// Recency heat on Loop's freshness scale: rested gray → aging yellow →
    /// insulin orange → stale red (last 3 used sites). Tier meaning is
    /// always also carried by text or shape, never color alone.
    static func color(for tier: SiteRecencyModel.Tier) -> Color {
        switch tier {
        case .base: restedShade
        case .relativelyRecent: aging
        case .recent: recent
        case .veryRecent: stale
        }
    }
}

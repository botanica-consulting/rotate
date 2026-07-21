import SwiftUI

enum AppTheme {
    /// Selected or recommended site.
    static let accent = Color.teal
    /// Recent placement history only.
    static let recent = Color.orange
    static let unavailable = Color.secondary

    static let cardCornerRadius: CGFloat = 20

    /// Recency heat: clear/base → yellow → orange → red (last 3 used sites).
    /// Tier meaning is always also carried by text or shape, never color alone.
    static func color(for tier: SiteRecencyModel.Tier) -> Color {
        switch tier {
        case .base: accent
        case .relativelyRecent: .yellow
        case .recent: .orange
        case .veryRecent: .red
        }
    }
}

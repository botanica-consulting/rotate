import SwiftUI
import UIKit

/// Palette and mark treatments borrowed from LoopKit/Loop
/// (Loop/DerivedAssetsBase.xcassets + LoopUI/Extensions/UIColor.swift), so
/// the journal reads as a sibling of the app it hands off to.
enum AppTheme {
    /// Loop's app accent ("accent" colorset → systemBlue).
    static let accent = Color(.systemBlue)

    /// Loop's glucose tint (#00B0FF light / #63BAFF dark).
    static let glucose = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x63 / 255, green: 0xBA / 255, blue: 0xFF / 255, alpha: 1)
            : UIColor(red: 0x00 / 255, green: 0xB0 / 255, blue: 0xFF / 255, alpha: 1)
    })

    /// Loop's insulin tint (systemOrange) — recent placements.
    static let recent = Color(.systemOrange)

    /// Loop's warning/aging color (#EAC345 light / systemYellow dark).
    static let aging = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .systemYellow
            : UIColor(red: 0xEA / 255, green: 0xC3 / 255, blue: 0x45 / 255, alpha: 1)
    })

    /// Loop's stale/critical color (systemRed) — the last three used sites.
    static let stale = Color(.systemRed)

    /// Rested areas: a neutral shade deeper than the bare silhouette so
    /// rested regions read as distinct, available real estate.
    static let restedShade = Color(.systemGray2)

    // Mounting-area treatment. Every surface that draws an area uses these
    // same parameters, so the rendering is identical at each location and
    // stays identical as more body types gain area assets.
    /// Loop's chart gridColor (systemGray3): the neutral outline every area gets.
    static let areaOutline = Color(.systemGray3)
    static let areaLineWidth: CGFloat = 1.5
    static let areaFillOpacity: CGFloat = 0.45
    /// Silhouettes recede behind the areas — lighter than a rested outline.
    static let silhouetteOpacity: CGFloat = 0.35

    static let cardCornerRadius: CGFloat = 20

    // Vignette-zoom treatment shared by the suggestion cards, the current-Pod
    // card, and the record sheet: one zoom level for focusing on a site, and
    // the soft radial crop's inner/outer radii as fractions of the frame.
    static let siteFocusZoom: CGFloat = 3.0
    static let vignetteInnerRatio: CGFloat = 0.28
    static let vignetteOuterRatio: CGFloat = 0.68

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

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

    /// The sensor track's tint: a calm teal-green, tuned for legibility in
    /// both appearances the same way `glucose` is. A different family from the
    /// pump's blue and from the recency warning colors (yellow/orange/red), so
    /// it distinguishes the track without ever reading as an alert.
    static let sensor = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x4A / 255, green: 0xD6 / 255, blue: 0xBE / 255, alpha: 1)
            : UIColor(red: 0x00 / 255, green: 0xB8 / 255, blue: 0x9E / 255, alpha: 1)
    })

    /// Subtle per-track tint so the pump and sensor read as distinct at a
    /// glance without shouting: the pump keeps Loop's glucose blue, the sensor
    /// its teal-green. Used on the age counters, the track chips, and the
    /// average-wear stats.
    static func tint(for device: DeviceType) -> Color {
        switch device {
        case .pump: glucose
        case .cgm: sensor
        }
    }

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

    /// Rested areas: a neutral shade set apart from the bare silhouette so
    /// rested regions read as distinct, available real estate. The
    /// relationship flips by appearance: in light mode a gray *deeper* than
    /// the faint silhouette reads as distinct; in dark mode a deeper shade
    /// would just merge into the dark body, so a *lighter* gray stands out
    /// instead.
    static let restedShade = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .systemGray       // lighter than the dark silhouette
            : .systemGray2      // deeper than the faint silhouette
    })

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
    /// Scales the current-site badge down on the small vignetted card so the
    /// Pod/sensor stays proportional to the compact figure there, rather than
    /// looming over it (see VignettedBodyThumbnail).
    static let currentBadgeCardScale: CGFloat = 0.6
    /// A gentle trim on the body-map markers so the Pod/sensor sits a touch
    /// lighter on each area.
    static let currentBadgeMapScale: CGFloat = 0.9

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

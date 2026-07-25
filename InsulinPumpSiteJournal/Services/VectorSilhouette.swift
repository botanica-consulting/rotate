import SwiftUI
import Synchronization

/// A body silhouette rendered as vector paths parsed straight from the bundled
/// SVG, rather than a rasterized `Image`. Because it draws as SwiftUI `Shape`s
/// — the same way the mounting-area highlights do — it stays crisp at any zoom
/// instead of pixelating when a card scales the figure up.
///
/// The bundled SVGs are machine-generated and deliberately simple: a handful of
/// solid-`fill` `<path>` elements using only M/C/Z commands, no gradients,
/// transforms, or nested styles — so a light-weight parse covers them fully.
struct SilhouetteArt {
    struct SubPath {
        let pathData: String
        let fill: Color
    }

    /// The SVG's coordinate box (its `width`/`height` in px); every path's
    /// coordinates live in this space, shared with the area catalog.
    let viewBox: CGSize
    let subPaths: [SubPath]

    var aspectRatio: CGFloat {
        viewBox.height == 0 ? 1 : viewBox.width / viewBox.height
    }

    /// Parsed art for an asset name (e.g. "body-neutral-front"), parsed once
    /// and cached — the files never change at runtime.
    static func named(_ name: String) -> SilhouetteArt? {
        cache.withLock { store in
            if let hit = store[name] { return hit ?? nil }
            let art = load(name)
            store[name] = .some(art)
            return art
        }
    }

    // `.some(nil)` marks "already tried, not found" so a missing file isn't
    // re-parsed every render.
    private static let cache = Mutex<[String: SilhouetteArt??]>([:])

    private static func load(_ name: String) -> SilhouetteArt? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "svg"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return parse(text)
    }

    static func parse(_ text: String) -> SilhouetteArt? {
        guard let w = firstDouble(text, #"\bwidth="([0-9.]+)px""#),
              let h = firstDouble(text, #"\bheight="([0-9.]+)px""#) else { return nil }

        var subPaths: [SubPath] = []
        for element in allMatches(text, #"<path[^>]*>"#) {
            guard let d = firstString(element, #"\bd="([^"]*)""#) else { continue }
            let fill = color(firstString(element, #"\bfill="([^"]*)""#)) ?? .gray
            subPaths.append(SubPath(pathData: d, fill: fill))
        }
        guard !subPaths.isEmpty else { return nil }
        return SilhouetteArt(viewBox: CGSize(width: w, height: h), subPaths: subPaths)
    }

    // MARK: - Tiny SVG-attribute scanning

    private static func firstString(_ text: String, _ pattern: String) -> String? {
        guard let regex = try? Regex(pattern),
              let match = try? regex.firstMatch(in: text),
              match.count > 1,
              let range = match[1].range else { return nil }
        return String(text[range])
    }

    private static func firstDouble(_ text: String, _ pattern: String) -> Double? {
        firstString(text, pattern).flatMap(Double.init)
    }

    private static func allMatches(_ text: String, _ pattern: String) -> [String] {
        guard let regex = try? Regex(pattern) else { return [] }
        return text.matches(of: regex).map { String(text[$0.range]) }
    }

    private static func color(_ hex: String?) -> Color? {
        guard var hex, hex.hasPrefix("#") else { return nil }
        hex.removeFirst()
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// One SVG sub-path mapped from its viewBox into the drawing rect — the same
/// transform `SiteAreaShape` uses, so silhouette and areas register exactly.
private struct SilhouettePathShape: Shape {
    let pathData: String
    let viewBox: CGSize

    private nonisolated static let parsedPaths = Mutex<[String: Path]>([:])

    func path(in rect: CGRect) -> Path {
        let base = Self.parsedPaths.withLock { cache in
            if let hit = cache[pathData] { return hit }
            let parsed = SVGPathParser.path(from: pathData)
            cache[pathData] = parsed
            return parsed
        }
        guard viewBox.width > 0, viewBox.height > 0 else { return base }
        return base.applying(CGAffineTransform(
            a: rect.width / viewBox.width, b: 0,
            c: 0, d: rect.height / viewBox.height,
            tx: rect.minX, ty: rect.minY
        ))
    }
}

/// Draws a `SilhouetteArt` as stacked filled shapes. Fills use the even-odd
/// rule the source SVGs declare (so interior cut-outs read correctly).
struct VectorSilhouette: View {
    let art: SilhouetteArt

    var body: some View {
        ZStack {
            ForEach(Array(art.subPaths.enumerated()), id: \.offset) { _, subPath in
                SilhouettePathShape(pathData: subPath.pathData, viewBox: art.viewBox)
                    .fill(subPath.fill, style: FillStyle(eoFill: true))
            }
        }
    }
}

/// The body figure for a body type and view, sized to its own aspect so an
/// overlaid area map (or badge) registers with it. Renders as crisp vector
/// paths when the bundled SVG parses; otherwise falls back to the rasterized
/// asset with high-quality interpolation. One place owns this so every surface
/// — cards and the body map — draws the figure identically.
struct BodySilhouette: View {
    let bodyType: BodyType
    let bodyView: PumpSite.BodyView

    var body: some View {
        let assetName = bodyType.assetName(for: bodyView)
        if let art = SilhouetteArt.named(assetName) {
            Color.clear
                .aspectRatio(art.aspectRatio, contentMode: .fit)
                .overlay {
                    VectorSilhouette(art: art)
                        .opacity(AppTheme.silhouetteOpacity)
                }
        } else {
            Image(assetName)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .opacity(AppTheme.silhouetteOpacity)
        }
    }
}

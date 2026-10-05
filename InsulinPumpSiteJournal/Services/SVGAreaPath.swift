import SwiftUI
import Synchronization

/// Minimal SVG path-data parser covering the commands the mounting-area
/// assets use (absolute/relative move, line, cubic curve, close).
enum SVGPathParser {
    // Called from Shape.path(in:), which is nonisolated.
    nonisolated static func path(from data: String) -> Path {
        var path = Path()
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var command: Character = "M"

        let scanner = Scanner(string: data)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: " ,\n\t")

        func scanPoint(relative: Bool) -> CGPoint? {
            guard let x = scanner.scanDouble(), let y = scanner.scanDouble() else { return nil }
            let point = CGPoint(x: x, y: y)
            return relative ? CGPoint(x: current.x + point.x, y: current.y + point.y) : point
        }

        while !scanner.isAtEnd {
            if let letter = scanner.scanCharacter(), letter.isLetter {
                command = letter
                if command == "Z" || command == "z" {
                    path.closeSubpath()
                    current = subpathStart
                    continue
                }
            } else {
                // A number while a draw command is active: repeat the command.
                scanner.currentIndex = data.index(before: scanner.currentIndex)
            }

            let relative = command.isLowercase
            switch Character(command.uppercased()) {
            case "M":
                guard let point = scanPoint(relative: relative) else { return path }
                path.move(to: point)
                current = point
                subpathStart = point
                command = relative ? "l" : "L"
            case "L":
                guard let point = scanPoint(relative: relative) else { return path }
                path.addLine(to: point)
                current = point
            case "C":
                guard let control1 = scanPoint(relative: relative),
                      let control2 = scanPoint(relative: relative),
                      let point = scanPoint(relative: relative) else { return path }
                path.addCurve(to: point, control1: control1, control2: control2)
                current = point
            default:
                // The area assets use only absolute M/L/C/Z. Anything else
                // (H, V, S, Q, T, A, or shorthand) would truncate the path
                // silently — surface it in debug builds so a bad asset is
                // caught, but still return what parsed in release.
                assertionFailure("SVGPathParser: unsupported command '\(command)'")
                return path
            }
        }
        return path
    }
}

/// The one mounting-area treatment: a tier-colored fill under a single
/// shared hairline outline. Every surface that draws an area renders through
/// this, so the look is identical at each location and for every body type.
struct SiteAreaHighlight: View {
    let area: SiteArea
    let fill: Color
    /// Set to the parent's scaleEffect so the stroke stays hairline when the
    /// figure is zoomed (cards zoom toward the area).
    var displayScale: CGFloat = 1

    var body: some View {
        let shape = SiteAreaShape(area: area)
        shape
            .fill(fill.opacity(AppTheme.areaFillOpacity))
            .overlay(shape.stroke(AppTheme.areaOutline, lineWidth: AppTheme.areaLineWidth / displayScale))
    }
}

/// A compact text pill naming the device track (Pump / Sensor), so the two
/// verticals stay distinguishable wherever their records share a surface (the
/// unified history list, the record sheet).
struct DeviceChip: View {
    let device: DeviceType

    var body: some View {
        let tint = AppTheme.tint(for: device)
        Text(device.displayName.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.15)))
            .accessibilityLabel(device.displayName)
    }
}

/// Parsed-path cache: area path data is static for the app's lifetime and
/// parsing is pure string work — do it once per area, not on every render of
/// every figure. Shared by both area shapes.
enum SiteAreaPathCache {
    private nonisolated static let parsedPaths = Mutex<[String: Path]>([:])

    // Called from Shape.path(in:), which is nonisolated.
    nonisolated static func path(for area: SiteArea) -> Path {
        parsedPaths.withLock { cache in
            if let hit = cache[area.pathData] {
                return hit
            }
            let parsed = SVGPathParser.path(from: area.pathData)
            cache[area.pathData] = parsed
            return parsed
        }
    }
}

/// Renders a `SiteArea` (path data in the silhouette's viewBox space) scaled
/// into the given rect — which must be the silhouette image's fitted frame.
struct SiteAreaShape: Shape {
    let area: SiteArea

    func path(in rect: CGRect) -> Path {
        SiteAreaPathCache.path(for: area).applying(CGAffineTransform(
            a: rect.width / area.viewBoxWidth, b: 0,
            c: 0, d: rect.height / area.viewBoxHeight,
            tx: rect.minX, ty: rect.minY
        ))
    }
}

/// The same area path drawn on its own, with no body under it: the shape is
/// lifted out of its place in the viewBox and re-fitted to the frame.
///
/// This is what a custom site looks like. A user-added site has no position on
/// the figure, so instead of a highlight somewhere on a silhouette it gets the
/// area shape floating by itself — recognisably the same visual language as
/// every other site, without claiming a place on the body.
struct FloatingAreaShape: Shape {
    let area: SiteArea
    /// Breathing room left around the shape, as a fraction of the frame, so the
    /// hairline outline never sits flush against the edge.
    var inset: CGFloat = 0.1

    func path(in rect: CGRect) -> Path {
        let base = SiteAreaPathCache.path(for: area)
        let bounds = base.boundingRect
        guard bounds.width > 0, bounds.height > 0 else { return Path() }

        let target = rect.insetBy(dx: rect.width * inset, dy: rect.height * inset)
        // Uniform scale: the blob keeps its own proportions whatever shape the
        // frame is.
        let scale = min(target.width / bounds.width, target.height / bounds.height)
        let transform = CGAffineTransform(translationX: -bounds.midX, y: -bounds.midY)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: target.midX, y: target.midY))
        return base.applying(transform)
    }
}

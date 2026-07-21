import SwiftUI

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

/// A miniature white Pod marking the site currently in use — the same
/// convention Insulet's own site map uses, so no colored border is needed.
/// Scales with Dynamic Type so it stays legible at accessibility sizes.
struct PodBadge: View {
    @ScaledMetric(relativeTo: .footnote) private var width: CGFloat = 21

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.28, style: .continuous)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.28, style: .continuous)
                    .stroke(Color(.systemGray3), lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: width * 0.19, height: width * 0.19)
                    .padding(.leading, width * 0.19)
            }
            .frame(width: width, height: width * 0.71)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}

/// Renders a `SiteArea` (path data in the silhouette's viewBox space) scaled
/// into the given rect — which must be the silhouette image's fitted frame.
struct SiteAreaShape: Shape {
    let area: SiteArea

    func path(in rect: CGRect) -> Path {
        SVGPathParser.path(from: area.pathData).applying(CGAffineTransform(
            a: rect.width / area.viewBoxWidth, b: 0,
            c: 0, d: rect.height / area.viewBoxHeight,
            tx: rect.minX, ty: rect.minY
        ))
    }
}

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

/// The one mounting-area treatment: an optional tier-colored fill (nil =
/// rested, clear) under a single shared hairline outline. Every surface that
/// draws an area renders through this, so the look is identical at each
/// location and for every body type.
struct SiteAreaHighlight: View {
    let area: SiteArea
    var fill: Color?
    var outline: Color = AppTheme.areaOutline
    /// Set to the parent's scaleEffect so the stroke stays hairline when the
    /// figure is zoomed (cards zoom toward the area).
    var displayScale: CGFloat = 1

    var body: some View {
        let shape = SiteAreaShape(area: area)
        shape
            .fill(fill.map { $0.opacity(AppTheme.areaFillOpacity) } ?? Color.clear)
            .overlay(shape.stroke(outline, lineWidth: AppTheme.areaLineWidth / displayScale))
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

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Renders the app icon: the Pod badge from the body map, scaled up, inside a
// circular rotation arrow in Loop's glucose blue. Usage:
//   swift scripts/render_app_icon.swift <output.png> [size]

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let size = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? 1024 : 1024
let scale = CGFloat(size) / 1024

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
    // No alpha channel: App Store icons must be opaque RGB.
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

// Draw in y-down design coordinates on a 1024 grid.
context.translateBy(x: 0, y: CGFloat(size))
context.scaleBy(x: scale, y: -scale)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

// MARK: Background — soft Loop-blue atmosphere, opaque (App Store rule).
let background = CGGradient(
    colorsSpace: colorSpace,
    colors: [rgb(0xFBFDFF), rgb(0xDCEEFB)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    background,
    start: .zero,
    end: CGPoint(x: 0, y: 1024),
    options: []
)

let center = CGPoint(x: 512, y: 512)

func rad(_ degrees: CGFloat) -> CGFloat { degrees * .pi / 180 }
func onCircle(_ degrees: CGFloat, radius: CGFloat) -> CGPoint {
    CGPoint(x: center.x + radius * cos(rad(degrees)), y: center.y + radius * sin(rad(degrees)))
}

// MARK: Rotation arrow — one thick arc, arrowhead on the leading end.
// Angles are y-down screen degrees: 0 = right, 90 = bottom, 180 = left.
let arrowColor = rgb(0x00B0FF) // Loop glucose blue
let arcRadius: CGFloat = 330
let arcWidth: CGFloat = 92
let tailDeg: CGFloat = 115 // tail at lower-left; gap sits at the bottom
let headDeg: CGFloat = 50  // head at lower-right after sweeping over the top

let arc = CGMutablePath()
// In the flipped (y-down) context, clockwise: false sweeps with increasing
// angle: tail (lower-left) → left → top → right → head (lower-right).
arc.addArc(center: center, radius: arcRadius, startAngle: rad(tailDeg), endAngle: rad(headDeg), clockwise: false)

// Arrowhead: triangle whose base sits just behind the arc's head end (hiding
// the seam), pointing along the sweep (tangent of increasing angle = +90°).
let baseDeg = headDeg - 2
let headBase = onCircle(baseDeg, radius: arcRadius)
let tangentDeg = baseDeg + 90
let tip = CGPoint(
    x: headBase.x + 150 * cos(rad(tangentDeg)),
    y: headBase.y + 150 * sin(rad(tangentDeg))
)
let across = CGVector(dx: cos(rad(baseDeg)), dy: sin(rad(baseDeg)))
let halfBase: CGFloat = 100
let head = CGMutablePath()
head.move(to: tip)
head.addLine(to: CGPoint(x: headBase.x + across.dx * halfBase, y: headBase.y + across.dy * halfBase))
head.addLine(to: CGPoint(x: headBase.x - across.dx * halfBase, y: headBase.y - across.dy * halfBase))
head.closeSubpath()

// One shape (stroked arc + head), filled with a light→dark run so the arrow
// deepens toward the head, like the reference art.
let arrowShape = CGMutablePath()
arrowShape.addPath(arc.copy(strokingWithWidth: arcWidth, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
arrowShape.addPath(head)
context.saveGState()
context.addPath(arrowShape)
context.clip()
let arrowGradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [rgb(0x3FC2FF), arrowColor, rgb(0x0089DB)] as CFArray,
    locations: [0, 0.45, 1]
)!
context.drawLinearGradient(
    arrowGradient,
    start: CGPoint(x: 512, y: 80),
    end: CGPoint(x: 512, y: 944),
    options: []
)
context.restoreGState()

// MARK: Pod — the body-map badge, blown up: white rounded rectangle,
// hairline gray outline, gray fill-port dot at the leading edge.
let podWidth: CGFloat = 400
let podHeight: CGFloat = podWidth * 0.71
let podCorner: CGFloat = podWidth * 0.28
let podRect = CGRect(
    x: center.x - podWidth / 2, y: center.y - podHeight / 2,
    width: podWidth, height: podHeight
)
let podPath = CGPath(roundedRect: podRect, cornerWidth: podCorner, cornerHeight: podCorner, transform: nil)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 34, color: rgb(0x003A66, 0.25))
context.addPath(podPath)
context.setFillColor(rgb(0xFFFFFF))
context.fillPath()
context.restoreGState()

context.addPath(podPath)
context.setStrokeColor(rgb(0xC7C7CC)) // systemGray3
context.setLineWidth(10)
context.strokePath()

let dotDiameter = podWidth * 0.19
let dotRect = CGRect(
    x: podRect.minX + podWidth * 0.15,
    y: center.y - dotDiameter / 2,
    width: dotDiameter, height: dotDiameter
)
context.setFillColor(rgb(0xD1D1D6)) // systemGray4
context.fillEllipse(in: dotRect)

// MARK: Write PNG.
let image = context.makeImage()!
let url = URL(fileURLWithPath: outputPath)
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("failed to write \(outputPath)")
}
print("wrote \(outputPath) (\(size)x\(size))")

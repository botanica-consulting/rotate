import SwiftUI

/// An original, genderless human silhouette drawn in a normalized unit space.
/// The same outline is used for the front and rear views; `BodyThumbnail`
/// adds a "Front"/"Rear" caption so orientation never depends on reading the
/// illustration.
struct BodySilhouette: Shape {
    var bodyView: PumpSite.BodyView

    // Right-half outline (viewer's right), authored as quad-curve segments in
    // unit space starting at the right side of the neck and ending at the
    // crotch (x = 0.5). The left half is the mirror, traversed in reverse.
    private static let neckRight = CGPoint(x: 0.545, y: 0.125)
    private static let rightHalf: [(to: CGPoint, control: CGPoint)] = [
        (CGPoint(x: 0.560, y: 0.185), CGPoint(x: 0.548, y: 0.155)), // neck side down
        (CGPoint(x: 0.735, y: 0.225), CGPoint(x: 0.640, y: 0.190)), // trapezius → shoulder tip
        (CGPoint(x: 0.790, y: 0.360), CGPoint(x: 0.790, y: 0.275)), // deltoid → elbow
        (CGPoint(x: 0.815, y: 0.480), CGPoint(x: 0.805, y: 0.420)), // forearm → wrist
        (CGPoint(x: 0.790, y: 0.550), CGPoint(x: 0.835, y: 0.525)), // around the hand
        (CGPoint(x: 0.745, y: 0.480), CGPoint(x: 0.750, y: 0.525)), // inner hand → inner wrist
        (CGPoint(x: 0.660, y: 0.300), CGPoint(x: 0.705, y: 0.390)), // inner arm up → armpit
        (CGPoint(x: 0.615, y: 0.445), CGPoint(x: 0.645, y: 0.375)), // ribcage → waist
        (CGPoint(x: 0.660, y: 0.560), CGPoint(x: 0.655, y: 0.505)), // waist → hip
        (CGPoint(x: 0.615, y: 0.740), CGPoint(x: 0.660, y: 0.655)), // outer thigh → knee
        (CGPoint(x: 0.580, y: 0.905), CGPoint(x: 0.610, y: 0.825)), // calf → ankle
        (CGPoint(x: 0.545, y: 0.965), CGPoint(x: 0.600, y: 0.958)), // around the foot
        (CGPoint(x: 0.530, y: 0.740), CGPoint(x: 0.518, y: 0.845)), // inner leg → inner knee
        (CGPoint(x: 0.502, y: 0.590), CGPoint(x: 0.526, y: 0.650)), // inner thigh → crotch
    ]

    func path(in rect: CGRect) -> Path {
        func point(_ p: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
        }
        func mirrored(_ p: CGPoint) -> CGPoint {
            CGPoint(x: 1 - p.x, y: p.y)
        }

        var path = Path()

        path.addEllipse(in: CGRect(
            x: rect.minX + 0.408 * rect.width,
            y: rect.minY + 0.020 * rect.height,
            width: 0.184 * rect.width,
            height: 0.110 * rect.height
        ))

        path.move(to: point(Self.neckRight))
        for segment in Self.rightHalf {
            path.addQuadCurve(to: point(segment.to), control: point(segment.control))
        }

        // Mirror back up the left side: segment i curves from destination i-1
        // to destination i, so the reverse traversal curves toward the
        // mirrored previous destination using the same (mirrored) control.
        let destinations = [Self.neckRight] + Self.rightHalf.map(\.to)
        for index in stride(from: Self.rightHalf.count - 1, through: 0, by: -1) {
            path.addQuadCurve(
                to: point(mirrored(destinations[index])),
                control: point(mirrored(Self.rightHalf[index].control))
            )
        }
        path.closeSubpath()

        return path
    }
}

#Preview("Silhouette") {
    HStack(spacing: 24) {
        BodySilhouette(bodyView: .front)
            .fill(Color.primary.opacity(0.15))
            .overlay(BodySilhouette(bodyView: .front).stroke(Color.primary.opacity(0.4), lineWidth: 1))
            .aspectRatio(0.45, contentMode: .fit)
        BodySilhouette(bodyView: .rear)
            .fill(Color.primary.opacity(0.15))
            .overlay(BodySilhouette(bodyView: .rear).stroke(Color.primary.opacity(0.4), lineWidth: 1))
            .aspectRatio(0.45, contentMode: .fit)
    }
    .padding()
}

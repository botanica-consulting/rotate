import SwiftUI

/// The two device marks — the pump's rounded-rectangle Pod and the CGM's round
/// puck — in one place, because both the app and the widget extension draw
/// them. They are the app's device identity: on the body map and the cards they
/// mark the site in use, and on the lock screen, where accessory widgets render
/// monochrome and colour can't distinguish the tracks, the silhouette is the
/// only thing that still can.
///
/// `scale` exists for the widget: the marks are sized for the body figure, and
/// an accessory family needs the same shape at a fraction of it.

/// A miniature white Pod marking the site currently in use — the same
/// convention Insulet's own site map uses, so no colored border is needed.
/// Fixed size on purpose: it marks a position on a fixed-size figure, so it
/// must not grow with Dynamic Type and swallow the area it sits on.
struct PodBadge: View {
    var scale: CGFloat = 1

    private var width: CGFloat { 21 * scale }

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.28, style: .continuous)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.28, style: .continuous)
                    .stroke(Color(.systemGray3), lineWidth: 1 * scale)
            )
            .overlay(alignment: .leading) {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: width * 0.19, height: width * 0.19)
                    .padding(.leading, width * 0.19)
            }
            .frame(width: width, height: width * 0.71)
            .shadow(color: .black.opacity(0.25), radius: 2 * scale, y: 1 * scale)
    }
}

/// A miniature white round sensor marking the CGM site currently in use. The
/// round puck shape reads as a sensor at a glance, distinct from the pump's
/// rounded-rectangle `PodBadge`. Fixed size for the same reason as PodBadge:
/// it marks a position on a fixed-size figure and must not swallow its area.
struct SensorBadge: View {
    var scale: CGFloat = 1

    private var diameter: CGFloat { 18 * scale }

    var body: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color(.systemGray3), lineWidth: 1 * scale))
            .overlay(
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: diameter * 0.34, height: diameter * 0.34)
            )
            .frame(width: diameter, height: diameter)
            .shadow(color: .black.opacity(0.25), radius: 2 * scale, y: 1 * scale)
    }
}

/// The current-site marker for a device track: the Pod's rounded-rectangle or
/// the sensor's round puck.
struct CurrentSiteBadge: View {
    let device: DeviceType
    var scale: CGFloat = 1

    var body: some View {
        switch device {
        case .pump: PodBadge(scale: scale)
        case .cgm: SensorBadge(scale: scale)
        }
    }
}

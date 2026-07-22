import SwiftUI

/// Technical readout of how long the current Pod has been on: "27h".
/// Self-contained so a future widget can reuse the same formatting —
/// widgets build timeline entries instead of TimelineView, so the text
/// helpers are static and date-driven.
struct PodAgeCounter: View {
    let placedAt: Date
    /// Track tint for the readout; defaults to the pump's glucose blue.
    var tint: Color = AppTheme.glucose

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(Self.text(at: context.date, since: placedAt))
                .font(.system(.subheadline, design: .monospaced).weight(.medium))
                .tracking(0.5)
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
    }

    /// Whole hours since placement: "0h" through "72h" and beyond.
    static func text(at now: Date, since placedAt: Date) -> String {
        "\(hours(at: now, since: placedAt))h"
    }

    static func spokenText(at now: Date, since placedAt: Date) -> String {
        "\(hours(at: now, since: placedAt)) hours"
    }

    private static func hours(at now: Date, since placedAt: Date) -> Int {
        max(0, Int(now.timeIntervalSince(placedAt) / 3600))
    }
}

#Preview("Pod age") {
    PodAgeCounter(placedAt: .now.addingTimeInterval(-27.5 * 3600))
        .padding()
}

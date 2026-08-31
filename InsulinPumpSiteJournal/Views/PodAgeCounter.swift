import SwiftUI

/// Technical readout of how long the current Pod has been on: "27h".
/// The formatting itself is `WearDuration`, shared with the widget — widgets
/// build timeline entries instead of using TimelineView, so the text helpers
/// have to be static and date-driven.
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

    /// Whole hours since placement: "0h" through "72h" and beyond. The
    /// arithmetic lives in `WearDuration`, shared with the widget extension so
    /// the two can never round differently.
    static func text(at now: Date, since placedAt: Date) -> String {
        WearDuration.text(at: now, since: placedAt)
    }

    static func spokenText(at now: Date, since placedAt: Date) -> String {
        WearDuration.spokenText(at: now, since: placedAt)
    }
}

#Preview("Pod age") {
    PodAgeCounter(placedAt: .now.addingTimeInterval(-27.5 * 3600))
        .padding()
}

import Foundation

/// How long a site has been on, in whole hours.
///
/// Split out of `PodAgeCounter` so the widget extension can use the exact same
/// arithmetic and wording without compiling a SwiftUI view — the app shows a
/// live `TimelineView`, the widget builds timeline entries, and both must round
/// identically or the two would disagree by an hour.
nonisolated enum WearDuration {
    /// Truncated whole hours, floored at zero.
    nonisolated static func hours(at now: Date, since placedAt: Date) -> Int {
        max(0, Int(now.timeIntervalSince(placedAt) / 3600))
    }

    /// "27h"
    nonisolated static func text(at now: Date, since placedAt: Date) -> String {
        "\(hours(at: now, since: placedAt))h"
    }

    /// "27 hours" — for VoiceOver and for Siri's spoken answer.
    nonisolated static func spokenText(at now: Date, since placedAt: Date) -> String {
        let count = hours(at: now, since: placedAt)
        return count == 1 ? "1 hour" : "\(count) hours"
    }

    /// When the hour count next ticks over. The widget schedules an entry at
    /// each of these so the number advances with no app involvement.
    nonisolated static func nextHourBoundary(after now: Date, since placedAt: Date) -> Date {
        let elapsed = max(0, now.timeIntervalSince(placedAt))
        let wholeHours = (elapsed / 3600).rounded(.down)
        return placedAt.addingTimeInterval((wholeHours + 1) * 3600)
    }
}

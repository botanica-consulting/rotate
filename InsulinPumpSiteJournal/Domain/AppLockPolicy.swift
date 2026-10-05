import Foundation

/// When a locked journal should ask for Face ID again.
///
/// Pure, so the rule is testable — `LAContext` is not something a unit test can
/// drive, but *when* to re-lock is the part with the actual decisions in it.
///
/// The grace period is not laziness. Confirming a placement can hand off to the
/// companion app (Loop), which backgrounds Rotate; without a grace period,
/// coming back to finish would demand Face ID every single time, and the whole
/// flow would be unusable enough that people would just turn the lock off. The
/// app-switcher shield already covers the case the grace period opens up —
/// someone glancing at the multitasking switcher sees no journal either way.
enum AppLockPolicy {
    /// How long the app may sit in the background and still come back unlocked.
    static let grace: TimeInterval = 60

    /// A cold launch has no previous active moment, so it always locks.
    static func shouldRelock(
        lastActiveAt: Date?,
        now: Date,
        grace: TimeInterval = grace
    ) -> Bool {
        guard let lastActiveAt else { return true }
        return now.timeIntervalSince(lastActiveAt) > grace
    }
}

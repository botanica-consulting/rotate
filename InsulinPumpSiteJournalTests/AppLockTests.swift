import Foundation
import Testing
@testable import InsulinPumpSiteJournal

/// The Face ID gate. `LAContext` can't be driven from a unit test, so what's
/// covered here is the part that holds the decisions: when a locked journal
/// should ask again, and the setting's default.
struct AppLockTests {
    @Test func lockIsOffUntilAskedFor() {
        let suite = UserDefaults(suiteName: "app-lock-tests-\(UUID().uuidString)")!
        defer { suite.removePersistentDomain(forName: suite.description) }

        // Off by default: a lock on every launch is a real cost, and 1.1.0
        // installs must not acquire one by upgrading.
        #expect(!AppLockSettings.isEnabled(defaults: suite))

        AppLockSettings.setEnabled(true, defaults: suite)
        #expect(AppLockSettings.isEnabled(defaults: suite))

        AppLockSettings.setEnabled(false, defaults: suite)
        #expect(!AppLockSettings.isEnabled(defaults: suite))
    }

    /// A cold launch has no previous active moment, so it must lock — this is
    /// the case that matters most and the one a "time since" rule gets wrong if
    /// it treats a missing date as "just now".
    @Test func aColdLaunchIsAlwaysLocked() {
        #expect(AppLockPolicy.shouldRelock(lastActiveAt: nil, now: .now))
    }

    /// Confirming a placement can hand off to Loop and come straight back. That
    /// round trip must not demand Face ID, or the lock makes the core flow
    /// unusable and people switch it off.
    @Test func aQuickTripToAnotherAppComesBackUnlocked() {
        let left = Date(timeIntervalSince1970: 1_750_000_000)
        let back = left.addingTimeInterval(AppLockPolicy.grace - 1)
        #expect(!AppLockPolicy.shouldRelock(lastActiveAt: left, now: back))
    }

    @Test func stayingAwayPastTheGraceRelocks() {
        let left = Date(timeIntervalSince1970: 1_750_000_000)
        let back = left.addingTimeInterval(AppLockPolicy.grace + 1)
        #expect(AppLockPolicy.shouldRelock(lastActiveAt: left, now: back))
    }

    /// Exactly on the boundary stays unlocked — the rule is "longer than", so
    /// the grace period is inclusive of its own end.
    @Test func theGraceBoundaryItselfStaysUnlocked() {
        let left = Date(timeIntervalSince1970: 1_750_000_000)
        #expect(!AppLockPolicy.shouldRelock(
            lastActiveAt: left,
            now: left.addingTimeInterval(AppLockPolicy.grace)
        ))
    }

    /// A clock that moves backwards (time zone change, NTP correction) must not
    /// read as "away for a negative time and therefore fine forever" — but it
    /// also shouldn't relock spuriously. Negative elapsed is not past the
    /// grace, so it stays unlocked, which is the same answer as no time having
    /// passed at all.
    @Test func aBackwardsClockDoesNotRelock() {
        let left = Date(timeIntervalSince1970: 1_750_000_000)
        #expect(!AppLockPolicy.shouldRelock(
            lastActiveAt: left,
            now: left.addingTimeInterval(-3600)
        ))
    }

    /// The availability check must never report something the device can't do —
    /// the toggle is hidden on `.none`, and `canAuthenticate` is what hides it.
    @Test func noAuthenticationMeansNoToggle() {
        #expect(!AppLock.Availability.none.canAuthenticate)
        #expect(AppLock.Availability.passcodeOnly.canAuthenticate)
    }
}

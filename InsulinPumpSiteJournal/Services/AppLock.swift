import LocalAuthentication
import Observation

/// Holds the locked/unlocked state of the journal and talks to
/// `LocalAuthentication`.
///
/// A singleton for the same reason `CloudKitPurgeController` is one: the state
/// has to outlive any particular view, and the system's Face ID sheet takes
/// scene focus, which tears view state down underneath it.
@MainActor
@Observable
final class AppLock {
    static let shared = AppLock()

    /// What the device can actually ask for. Checked live rather than cached:
    /// a user can enrol or remove Face ID while the app is installed.
    enum Availability: Equatable {
        /// Face ID or Touch ID, with the passcode as the system's own fallback.
        case biometric(LABiometryType)
        /// No biometry enrolled, but a passcode is set.
        case passcodeOnly
        /// Neither. Nothing can be asked for, so nothing may be required.
        case none

        var canAuthenticate: Bool { self != .none }
    }

    private(set) var isLocked: Bool
    /// Why the last attempt failed, for the lock screen to show. Cancelling is
    /// not a failure, so it stays nil for that.
    private(set) var failureMessage: String?
    /// True while the system sheet is up. Scene-phase changes are ignored for
    /// the duration: presenting it makes the app inactive, which would
    /// otherwise look exactly like the user leaving and re-lock underneath.
    private(set) var isAuthenticating = false

    private var lastActiveAt: Date?

    private init() {
        // Locked from the start when the setting is on: a cold launch must not
        // render the journal for even one frame before asking.
        isLocked = AppLockSettings.isEnabled() && Self.availability().canAuthenticate
    }

    static func availability(context: LAContext = LAContext()) -> Availability {
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return .biometric(context.biometryType)
        }
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            return .passcodeOnly
        }
        return .none
    }

    /// Asks for Face ID / Touch ID / passcode and unlocks on success.
    ///
    /// `deviceOwnerAuthentication`, not `...WithBiometrics`: the passcode
    /// fallback is what stops a failed or unenrolled Face ID from locking
    /// someone out of their own journal.
    func authenticate() async {
        guard isLocked, !isAuthenticating else { return }

        let context = LAContext()
        guard Self.availability(context: context).canAuthenticate else {
            // Nothing to ask for — never leave the journal unreachable.
            unlock()
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your journal"
            )
            if ok { unlock() }
        } catch let error as LAError where error.code == .userCancel
            || error.code == .appCancel
            || error.code == .systemCancel {
            // Deliberate dismissal. Stay locked, say nothing.
            failureMessage = nil
        } catch {
            failureMessage = error.localizedDescription
        }
    }

    /// Called when the setting is switched on, so the lock takes effect at the
    /// next open rather than immediately — the user is already looking at the
    /// journal, and locking them out of the screen they are on is absurd.
    func settingChanged(to enabled: Bool) {
        if !enabled {
            unlock()
        }
        lastActiveAt = .now
    }

    // MARK: Scene phase

    func sceneWentInactive(at date: Date = .now) {
        guard !isAuthenticating else { return }
        lastActiveAt = date
    }

    func sceneBecameActive(at date: Date = .now) {
        guard !isAuthenticating else { return }
        guard AppLockSettings.isEnabled(), Self.availability().canAuthenticate else {
            unlock()
            return
        }
        if AppLockPolicy.shouldRelock(lastActiveAt: lastActiveAt, now: date) {
            isLocked = true
            failureMessage = nil
        }
    }

    private func unlock() {
        isLocked = false
        failureMessage = nil
        lastActiveAt = .now
    }

    #if DEBUG
    /// UI tests run with the lock off; this keeps the singleton from carrying a
    /// locked state into a test launch.
    func unlockForTesting() { unlock() }
    #endif
}

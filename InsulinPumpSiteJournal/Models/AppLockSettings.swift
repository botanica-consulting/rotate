import Foundation

/// Whether the journal is locked behind Face ID (or Touch ID, or the device
/// passcode) when the app opens.
///
/// Off by default: the journal is not a vault, and a lock on every launch is a
/// real cost for something people open several times a day. It exists because
/// where you place a pump is medical information, and a phone gets handed
/// around.
///
/// Separate from the app-switcher shield, which is unconditional — hiding the
/// snapshot iOS takes costs the user nothing, so it is not a setting.
enum AppLockSettings {
    static let storageKey = "requireUnlockOnOpen"

    /// Absent means off, which `bool(forKey:)` already gives us.
    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: storageKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: storageKey)
    }
}

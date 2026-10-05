import Foundation

/// What changed in a release, shown once to anyone upgrading.
///
/// New installs see the setup wizard instead and are stamped as current, so
/// nobody gets both. Adding a release means one entry here.
struct ReleaseNotes: Identifiable {
    struct Point {
        let icon: String
        let title: String
        let text: String
    }

    let version: String
    let points: [Point]

    var id: String { version }

    /// The key holding the newest version whose notes have been shown.
    static let lastSeenVersionKey = "lastSeenVersion"

    /// Newest first.
    static let all: [ReleaseNotes] = [
        ReleaseNotes(
            version: "1.1.1",
            points: [
                Point(
                    icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    title: "Fix times after the fact",
                    text: "Tap any entry to change when a site went on or came off — no more deleting a placement just because you logged it in the morning."
                ),
                Point(
                    icon: "plus.circle.fill",
                    title: "Custom sites",
                    text: "Settings → Custom sites lets you add spots the figure doesn't cover. They rotate, collect recency heat, and can be excluded per track like any other area — they just show as a plain area instead of a place on the body."
                ),
                Point(
                    icon: "icloud.slash.fill",
                    title: "Turn iCloud sync off",
                    text: "Sync stays on by default, but you can now keep the journal on this device only — and remove the copy already in your iCloud. Settings → iCloud sync."
                ),
                Point(
                    icon: "mic.fill",
                    title: "Siri and a lock-screen widget",
                    text: "Ask Siri how long your site has been on, or start the next one hands-free. Add the Rotate widget to your lock screen for the hour count at a glance — tap it to start a new site."
                ),
                Point(
                    icon: "hand.raised.fill",
                    title: "Clearer about your data",
                    text: "The privacy wording now says plainly that Apple stores the synced copy while sync is on, and the app hides your journal in the app switcher."
                ),
            ]
        ),
    ]

    /// The notes to show someone whose last-seen version is `lastSeen`, newest
    /// first.
    ///
    /// Only asked for an existing user — a new install walks the wizard, which
    /// already carries the current wording — so a missing `lastSeen` means they
    /// upgraded from a build that predates this mechanism, and they get
    /// everything up to the version now installed.
    static func unseen(lastSeen: String?, current: String) -> [ReleaseNotes] {
        let seen = (lastSeen?.isEmpty ?? true) ? nil : lastSeen
        return all.filter { notes in
            let unseen = seen.map { isOlder($0, than: notes.version) } ?? true
            // Never show notes for a version newer than the one running.
            return unseen && !isOlder(current, than: notes.version)
        }
    }

    /// Numeric component compare, so "1.10.0" is newer than "1.9.0" and a
    /// missing component reads as zero ("1.1" == "1.1.0").
    static func isOlder(_ lhs: String, than rhs: String) -> Bool {
        let left = components(lhs)
        let right = components(rhs)
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }
}

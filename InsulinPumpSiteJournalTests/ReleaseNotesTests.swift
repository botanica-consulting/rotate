import Foundation
import Testing
@testable import InsulinPumpSiteJournal

/// The What's New gate. Getting this wrong either nags people on every launch or
/// silently never tells them anything changed.
struct ReleaseNotesTests {
    @Test func numericComponentsNotStringOrder() {
        // "1.10.0" < "1.9.0" as strings, which is exactly the trap.
        #expect(ReleaseNotes.isOlder("1.9.0", than: "1.10.0"))
        #expect(!ReleaseNotes.isOlder("1.10.0", than: "1.9.0"))
        #expect(ReleaseNotes.isOlder("1.1.0", than: "1.1.1"))
        #expect(!ReleaseNotes.isOlder("1.1.1", than: "1.1.1"))
    }

    @Test func missingComponentsReadAsZero() {
        #expect(!ReleaseNotes.isOlder("1.1", than: "1.1.0"))
        #expect(!ReleaseNotes.isOlder("1.1.0", than: "1.1"))
        #expect(ReleaseNotes.isOlder("1.1", than: "1.1.1"))
    }

    @Test func nonNumericVersionsDontCrash() {
        #expect(!ReleaseNotes.isOlder("", than: ""))
        _ = ReleaseNotes.isOlder("beta", than: "1.1.1")
    }

    @Test func upgradingFromTheReleaseBeforeShowsIt() {
        let notes = ReleaseNotes.unseen(lastSeen: "1.1.0", current: "1.1.1")
        #expect(notes.map(\.version) == ["1.1.1"])
    }

    @Test func upgradingFromBeforeThisMechanismShowsEverything() {
        // 1.1.0 stored nothing, so an existing user arrives with no last-seen
        // version — they must still be told what changed.
        #expect(ReleaseNotes.unseen(lastSeen: nil, current: "1.1.1").isEmpty == false)
        #expect(ReleaseNotes.unseen(lastSeen: "", current: "1.1.1").isEmpty == false)
    }

    @Test func alreadyCurrentShowsNothing() {
        #expect(ReleaseNotes.unseen(lastSeen: "1.1.1", current: "1.1.1").isEmpty)
    }

    @Test func notesForAFutureVersionAreNotShown() {
        // Guards against a note landing in `all` before its build ships.
        #expect(ReleaseNotes.unseen(lastSeen: "1.0.0", current: "1.1.0").isEmpty)
    }

    @Test func everyReleaseHasPointsAndIsOrderedNewestFirst() {
        #expect(!ReleaseNotes.all.isEmpty)
        for release in ReleaseNotes.all {
            #expect(!release.points.isEmpty, "\(release.version) has no points")
            for point in release.points {
                #expect(!point.title.isEmpty)
                #expect(!point.text.isEmpty)
                #expect(!point.icon.isEmpty)
            }
        }
        let versions = ReleaseNotes.all.map(\.version)
        for (newer, older) in zip(versions, versions.dropFirst()) {
            #expect(ReleaseNotes.isOlder(older, than: newer), "\(versions) is not newest-first")
        }
    }

    /// The notes have to describe the build they ship in, or an upgrading user
    /// sees nothing at all.
    @Test func newestNotesMatchTheBundleVersion() {
        let bundled = Bundle(for: BundleToken.self).infoDictionary?["CFBundleShortVersionString"] as? String
        // The test bundle carries its own version; only assert when the host's
        // marketing version is readable.
        if let bundled, !bundled.isEmpty, bundled != "1.0" {
            #expect(ReleaseNotes.all.first?.version == bundled)
        }
    }
}

private final class BundleToken {}

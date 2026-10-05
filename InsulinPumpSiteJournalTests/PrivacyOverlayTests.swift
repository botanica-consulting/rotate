import Testing
import UIKit
@testable import InsulinPumpSiteJournal

/// The app-switcher shield and the lock screen live in their own window so they
/// cover sheets. The regression this guards is specific: as overlays on the
/// root view they covered the journal and nothing else, so the body map,
/// Settings, a record's detail and the new-placement flow all reached the app
/// switcher in the clear.
@MainActor
struct PrivacyOverlayTests {
    /// Above `.alert`, or a presented sheet still wins and we are back to the
    /// bug. This level is the whole point of the window.
    @Test func theCoverSitsAboveSheetsAndAlerts() {
        let overlay = PrivacyOverlayWindow.shared
        defer { overlay.show(.none) }

        overlay.show(.shield)
        let window = try? #require(Self.coverWindow())
        #expect(window != nil, "no cover window was installed")
        if let window {
            #expect(window.windowLevel > .alert)
            #expect(!window.isHidden)
        }
    }

    /// The shield only has to be seen; the lock screen has a button on it.
    @Test func onlyTheLockScreenTakesTouches() {
        let overlay = PrivacyOverlayWindow.shared
        defer { overlay.show(.none) }

        overlay.show(.shield)
        #expect(Self.coverWindow()?.isUserInteractionEnabled == false)

        overlay.show(.lock)
        #expect(Self.coverWindow()?.isUserInteractionEnabled == true)
    }

    @Test func showingNoneTearsTheWindowDown() {
        let overlay = PrivacyOverlayWindow.shared
        overlay.show(.shield)
        #expect(Self.coverWindow() != nil)

        overlay.show(.none)
        #expect(Self.coverWindow() == nil, "the cover window outlived its content")
    }

    /// Asking for what is already up must not rebuild the window — a rebuild
    /// mid-transition is what makes a shield flicker into the snapshot.
    @Test func repeatingTheSameRequestIsANoOp() {
        let overlay = PrivacyOverlayWindow.shared
        defer { overlay.show(.none) }

        overlay.show(.shield)
        let first = Self.coverWindow()
        overlay.show(.shield)
        #expect(Self.coverWindow() === first)
    }

    /// Finds the overlay's window by the property that defines it, rather than
    /// by reaching into the type's privates.
    private static func coverWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.windowLevel > .alert && !$0.isHidden }
    }
}

import SwiftUI
import UIKit

/// Puts the app-switcher shield and the lock screen in a window of their own.
///
/// Both started as `.overlay`s on `AppRootView`'s content, which covered the
/// journal and nothing else. A sheet is presented *above* that hierarchy, so
/// the body map, Settings, a record's detail, What's New and the whole
/// new-placement `fullScreenCover` all went into the app-switcher snapshot in
/// the clear — the shield appeared to work, because it does work on the one
/// screen that isn't a modal. Attaching an overlay to each of the six
/// presentations would have made a seventh one a fresh leak.
///
/// A separate window above `.alert` covers everything in the scene, so
/// coverage no longer depends on where the user happens to be standing.
@MainActor
final class PrivacyOverlayWindow {
    static let shared = PrivacyOverlayWindow()

    enum Content: Equatable {
        case none
        /// Non-interactive: it only has to be in the snapshot.
        case shield
        /// Interactive — it carries the unlock button.
        case lock
    }

    private var window: UIWindow?
    private var shown: Content = .none

    private init() {}

    func show(_ wanted: Content) {
        guard wanted != shown else { return }
        shown = wanted

        switch wanted {
        case .none:
            window?.isHidden = true
            window = nil
        case .shield:
            install(AnyView(PrivacyShieldView()), interactive: false)
        case .lock:
            install(AnyView(AppLockView()), interactive: true)
        }
    }

    private func install(_ content: AnyView, interactive: Bool) {
        guard let scene = Self.foregroundScene() else {
            // No scene to attach to. The root-view overlays are still in place,
            // so the journal itself stays covered even here.
            shown = .none
            return
        }

        let host = UIHostingController(rootView: content)
        // The window must not be see-through: the point is that nothing behind
        // it reaches the snapshot. `AppBackground` paints an opaque
        // `systemBackground` base itself; this is belt and braces for the frame
        // before SwiftUI has drawn.
        host.view.backgroundColor = .systemBackground

        let window = self.window ?? UIWindow(windowScene: scene)
        // Above sheets, alerts and the keyboard.
        window.windowLevel = .alert + 1
        window.isUserInteractionEnabled = interactive
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }

    private static func foregroundScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        // While backgrounding, the scene is no longer foregroundActive — so
        // take any non-background scene, then fall back to whatever exists.
        return scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first { $0.activationState == .foregroundInactive }
            ?? scenes.first
    }
}

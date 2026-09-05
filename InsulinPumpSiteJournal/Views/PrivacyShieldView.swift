import SwiftUI

/// What the app switcher gets to see instead of the journal.
///
/// Its own type because it is rendered in two places: as an overlay on the root
/// view, and — so it also covers sheets — in `PrivacyOverlayWindow`.
struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            AppBackground()
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

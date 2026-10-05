import LocalAuthentication
import SwiftUI

/// What you see instead of the journal while it's locked.
///
/// Deliberately the same furniture as the app-switcher shield — background and
/// mark, nothing else — so a locked app and a backgrounded app look alike and
/// neither leaks a site, a date, or a note.
struct AppLockView: View {
    var lock = AppLock.shared

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 22) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 7)

                Text("Journal locked")
                    .font(.title3.weight(.semibold))

                if let message = lock.failureMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    Task { await lock.authenticate() }
                } label: {
                    Label(unlockTitle, systemImage: unlockIcon)
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("unlockButton")
            }
        }
        .ignoresSafeArea()
        // Asks straight away, so the common case is one glance and no tap. The
        // button is the retry path after a cancel or a failure.
        .task { await lock.authenticate() }
    }

    private var unlockTitle: String {
        switch AppLock.availability() {
        case .biometric(.faceID): "Unlock with Face ID"
        case .biometric(.touchID): "Unlock with Touch ID"
        case .biometric, .passcodeOnly: "Unlock"
        case .none: "Unlock"
        }
    }

    private var unlockIcon: String {
        switch AppLock.availability() {
        case .biometric(.faceID): "faceid"
        case .biometric(.touchID): "touchid"
        case .biometric, .passcodeOnly, .none: "lock.open"
        }
    }
}

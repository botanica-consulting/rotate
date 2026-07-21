import SwiftUI

/// Shown inside the new-Pod flow after a placement is saved. Instructs the
/// user to continue Pod activation in Loop. Deliberately does not attempt to
/// launch Loop — that requires a verified integration mechanism and is
/// deferred.
struct LoopHandoffView: View {
    let site: PumpSite
    let onContinue: () -> Void
    let onChooseAnother: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)

            Text("Site saved")
                .font(.largeTitle.bold())

            Text("\(site.title) has been added to your history.")
                .font(.body)
                .multilineTextAlignment(.center)

            Text("Now open Loop and continue activating and pairing your new Pod.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Continue in Loop")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(AppTheme.accent)
            .controlSize(.large)
            .accessibilityIdentifier("continueInLoopButton")

            Button {
                onChooseAnother()
            } label: {
                Text("Choose another site")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .accessibilityIdentifier("chooseAnotherSiteButton")

            Text("You can close this app and switch to Loop.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(24)
    }
}

#Preview("Handoff") {
    LoopHandoffView(site: PumpSite.catalog[4], onContinue: {}, onChooseAnother: {})
}

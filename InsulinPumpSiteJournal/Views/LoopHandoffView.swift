import SwiftUI

/// Shown inside the new-Pod flow after a placement is saved: placement
/// instructions for the chosen site, then the handoff to Loop. Deliberately
/// does not attempt to launch Loop — that requires a verified integration
/// mechanism and is deferred.
struct LoopHandoffView: View {
    let site: PumpSite
    let onContinue: () -> Void
    let onChooseAnother: () -> Void

    @AppStorage(MeasurementUnit.storageKey) private var unitRaw = MeasurementUnit.system.rawValue

    private var unit: MeasurementUnit {
        MeasurementUnit(rawValue: unitRaw) ?? .system
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Place your Pod")
                .font(.largeTitle.bold())

            Text("\(site.title) is saved to your history.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 14) {
                instruction(unit.spacingInstruction, systemImage: "ruler")
                instruction(
                    "Keep clear of waistbands and spots where clothing rubs.",
                    systemImage: "tshirt"
                )
                instruction(
                    "Clean the skin and let it dry fully before applying.",
                    systemImage: "drop"
                )
                instruction(
                    "When the Pod is on, open Loop to activate and pair it.",
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: .rect(cornerRadius: AppTheme.cardCornerRadius))

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

    private func instruction(_ text: String, systemImage: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)
        }
        .font(.callout)
    }
}

#Preview("Handoff") {
    LoopHandoffView(site: PumpSite.catalog[4], onContinue: {}, onChooseAnother: {})
}

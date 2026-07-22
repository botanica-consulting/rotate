import SwiftUI

/// Shown inside the new-Pod flow after choosing a site: placement
/// instructions, then the confirm-and-hand-off step. Nothing is saved until
/// the primary button — confirming records the placement and continues in
/// the companion app chosen in Settings. The label trusts the setting, not
/// `canOpenURL` — that check proved unreliable on device, and opening is
/// harmless when the companion is absent (the save still happens).
struct LoopHandoffView: View {
    let site: PumpSite
    let onConfirm: () -> Void
    let onChooseAnother: () -> Void

    @AppStorage(MeasurementUnit.storageKey) private var unitRaw = MeasurementUnit.system.rawValue
    @AppStorage(CompanionApp.storageKey) private var companionRaw = CompanionApp.loop.rawValue

    private var unit: MeasurementUnit {
        MeasurementUnit(rawValue: unitRaw) ?? .system
    }

    private var companion: CompanionApp {
        CompanionApp(rawValue: companionRaw) ?? .loop
    }

    private var handsOffToCompanion: Bool {
        companion.launchURL != nil
    }

    var body: some View {
        // ScrollView so accessibility text sizes grow past the screen
        // instead of clipping.
        ScrollView {
            VStack(spacing: 16) {
                Text("Place your Pod")
                    .font(.largeTitle.bold())
                    .padding(.top, 32)

                Text("\(site.title) is saved to your journal when you confirm below.")
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
            }
            .padding(.horizontal, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 16) {
                Button {
                    onConfirm()
                } label: {
                    Text(handsOffToCompanion
                        ? "Continue in \(companion.displayName)"
                        : "Pod is on — Save")
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

                Text(handsOffToCompanion
                    ? "Continuing saves the placement and opens \(companion.displayName)."
                    : "Confirming saves the placement. Then open Loop to pair.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
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
    LoopHandoffView(site: PumpSite.catalog[4], onConfirm: {}, onChooseAnother: {})
}

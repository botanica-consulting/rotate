import SwiftUI

/// Shown inside the new-Pod flow after choosing a site: placement
/// instructions, then the confirm-and-hand-off step. Nothing is saved until
/// the primary button — confirming records the placement and continues in
/// the companion app chosen in Settings. The label trusts the setting, not
/// `canOpenURL` — that check proved unreliable on device, and opening is
/// harmless when the companion is absent (the save still happens).
struct LoopHandoffView: View {
    let site: PumpSite
    let deviceType: DeviceType
    let onConfirm: () -> Void

    /// The companion for *this* track — pump and sensor are set separately, so
    /// the AppStorage key is device-specific and bound in init.
    @AppStorage private var companionRaw: String

    init(site: PumpSite, deviceType: DeviceType = .pump, onConfirm: @escaping () -> Void) {
        self.site = site
        self.deviceType = deviceType
        self.onConfirm = onConfirm
        self._companionRaw = AppStorage(
            wrappedValue: CompanionApp.loop.rawValue,
            CompanionApp.storageKey(for: deviceType)
        )
    }

    /// Placement distances always follow the device's measurement system —
    /// there's no unit setting to override it.
    private let unit: MeasurementUnit = .system

    private var companion: CompanionApp {
        CompanionApp(rawValue: companionRaw) ?? .loop
    }

    private var handsOffToCompanion: Bool {
        companion.launchURL != nil
    }

    /// Where the last step tells the user to go to activate the device — the
    /// chosen companion by name, or a neutral phrase when none is set.
    private var activationTarget: String {
        // With no companion set, don't name Loop — point at a neutral app so
        // the step matches the "…is on — Save" button (which opens nothing).
        handsOffToCompanion ? companion.displayName : (deviceType == .pump ? "your pump app" : "your sensor app")
    }

    var body: some View {
        // ScrollView so accessibility text sizes grow past the screen
        // instead of clipping.
        ScrollView {
            VStack(spacing: 16) {
                Text("Place your \(deviceType.noun)")
                    .font(.largeTitle.bold())
                    .padding(.top, 32)

                Text("\(site.title) is saved to your journal when you confirm below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(instructions.enumerated()), id: \.offset) { _, step in
                        instruction(step.text, systemImage: step.symbol)
                    }
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
                        : "\(deviceType.nounCapitalized) is on — Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(AppTheme.accent)
                .controlSize(.large)
                .accessibilityIdentifier("continueInLoopButton")

                Text(handsOffToCompanion
                    ? "Continuing saves the placement and opens \(companion.displayName)."
                    : "Confirming saves the placement.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    /// Device-specific placement guidance. The last step names the companion
    /// so it stays aligned with the confirm button.
    private var instructions: [(text: String, symbol: String)] {
        switch deviceType {
        case .pump:
            return [
                (unit.spacingInstruction(for: .pump), "ruler"),
                ("Keep clear of waistbands and spots where clothing rubs.", "tshirt"),
                ("Clean the skin and let it dry fully before applying.", "drop"),
                ("When the Pod is on, open \(activationTarget) to activate and pair it.",
                 "arrow.triangle.2.circlepath"),
            ]
        case .cgm:
            return [
                (unit.spacingInstruction(for: .cgm), "ruler"),
                ("Use the back of an upper arm or the abdomen. Avoid scars, moles, and bony spots.",
                 "target"),
                ("Clean the skin with an alcohol wipe and let it dry fully before applying.", "drop"),
                ("Press firmly around the edge for a few seconds so the adhesive sticks.", "hand.tap"),
                ("When the sensor is on, open \(activationTarget) to start it.",
                 "arrow.triangle.2.circlepath"),
            ]
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
    LoopHandoffView(site: PumpSite.catalog[4], onConfirm: {})
}

import SwiftUI
import SwiftData

/// App settings: the silhouette the body map renders, the companion app the
/// new-Pod flow hands off to, and the journal reset. Placement distances
/// always follow the device's measurement system, so there's no unit setting.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(CompanionApp.storageKey(for: .pump)) private var pumpCompanionRaw = CompanionApp.loop.rawValue
    @AppStorage(CompanionApp.storageKey(for: .cgm)) private var sensorCompanionRaw = CompanionApp.loop.rawValue
    @AppStorage(BodyType.storageKey) private var bodyTypeRaw = BodyType.neutral.rawValue
    // Observed so the "Rotation areas" summaries refresh when the sub-screens
    // change them.
    @AppStorage(RegionSettings.storageKey(for: .pump)) private var pumpDisabledRegions = ""
    @AppStorage(RegionSettings.storageKey(for: .cgm)) private var sensorDisabledRegions = ""
    @State private var confirmingReset = false
    /// Typed reset confirmation — the journal now syncs, so a reset reaches
    /// every device. Deleting requires typing RESET, not just a second tap.
    @State private var resetConfirmationText = ""
    @State private var resetError: Error?

    var body: some View {
        NavigationStack {
            Form {
                silhouetteSection
                regionsSection
                companionSection
                resetSection
                aboutSection
            }
            .alert(
                "Delete all placement records?",
                isPresented: $confirmingReset
            ) {
                TextField("Type RESET to confirm", text: $resetConfirmationText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .accessibilityIdentifier("resetConfirmationField")
                Button("Delete all records", role: .destructive) {
                    resetJournal()
                }
                .disabled(resetConfirmationText != "RESET")
                .accessibilityIdentifier("confirmResetButton")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes your placement history here and, through iCloud, from your other devices. It can't be undone. Type RESET to confirm.")
            }
            .onChange(of: confirmingReset) { _, isPresented in
                if !isPresented { resetConfirmationText = "" }
            }
            .alert(
                "Couldn't reset the journal",
                isPresented: Binding(
                    get: { resetError != nil },
                    set: { if !$0 { resetError = nil } }
                ),
                presenting: resetError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text("Nothing was deleted. \(error.localizedDescription)")
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("closeSettingsButton")
                }
            }
        }
    }

    @ViewBuilder
    private var silhouetteSection: some View {
        Section {
            NavigationLink {
                SilhouettePickerView()
            } label: {
                HStack {
                    Text("Silhouette")
                    Spacer()
                    Image(selectedBodyType.assetName(for: .front))
                        .resizable()
                        .scaledToFit()
                        .opacity(AppTheme.silhouetteOpacity)
                        .frame(width: 20, height: 40)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityIdentifier("silhouetteLink")
            .accessibilityLabel("Silhouette, currently \(selectedBodyType.displayName)")
        } header: {
            Text("Silhouette")
        } footer: {
            Text("The figure shown on the body map and site previews.")
        }
    }

    @ViewBuilder
    private var regionsSection: some View {
        Section {
            regionLink(for: .pump, disabledRaw: pumpDisabledRegions)
            regionLink(for: .cgm, disabledRaw: sensorDisabledRegions)
        } header: {
            Text("Rotation areas")
        } footer: {
            Text("Choose which body regions each track rotates through. Every region is on by default; turn off any you don't use.")
        }
    }

    private func regionLink(for device: DeviceType, disabledRaw: String) -> some View {
        let total = PumpSite.Region.allCases.count
        let enabled = total - RegionSettings.parse(disabledRaw).count
        return NavigationLink {
            RegionSettingsView(device: device)
        } label: {
            HStack {
                Text(device.displayName)
                Spacer()
                Text(enabled == total ? "All areas" : "\(enabled) of \(total)")
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier(device == .pump ? "pumpRegionsLink" : "sensorRegionsLink")
        .accessibilityLabel("\(device.displayName) areas, \(enabled) of \(total) on")
    }

    @ViewBuilder
    private var companionSection: some View {
        Section {
            Picker("Pump", selection: $pumpCompanionRaw) {
                ForEach(CompanionApp.options(for: .pump)) { app in
                    Text(app.displayName).tag(app.rawValue)
                }
            }
            .accessibilityIdentifier("pumpCompanionPicker")
            Picker("Sensor", selection: $sensorCompanionRaw) {
                ForEach(CompanionApp.options(for: .cgm)) { app in
                    Text(app.displayName).tag(app.rawValue)
                }
            }
            .accessibilityIdentifier("sensorCompanionPicker")
        } header: {
            Text("Companion apps")
        } footer: {
            Text("Confirming a placement opens that track's app to activate and pair it — the pump and sensor can differ. Choose None to keep everything in Rotate.")
        }
    }

    @ViewBuilder
    private var resetSection: some View {
        Section {
            Button("Reset journal…", role: .destructive) {
                confirmingReset = true
            }
            .accessibilityIdentifier("resetJournalButton")
        } footer: {
            Text("Deletes every placement record — pump and sensor — here and from iCloud on your other devices. Settings are kept.")
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
                .accessibilityIdentifier("appVersionRow")
            LabeledContent("Build", value: appBuild)
                .accessibilityIdentifier("appBuildRow")
        } header: {
            Text("About")
        } footer: {
            Text("Privacy: your journal is stored on this device and syncs through your private iCloud database, readable only by your Apple Account. No third-party servers are involved.")
        }
    }

    private var selectedBodyType: BodyType {
        BodyType(rawValue: bodyTypeRaw) ?? .neutral
    }

    /// Marketing version (CFBundleShortVersionString), e.g. "1.0.3".
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// Build number (CFBundleVersion) — the fastlane beta lane stamps this
    /// with a UTC timestamp per upload.
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private func resetJournal() {
        do {
            try JournalStore(context: modelContext).reset()
            dismiss()
        } catch {
            resetError = error
        }
    }
}

/// A dedicated screen for choosing the silhouette by sight: each option shows
/// the actual front figure it will render, so the choice isn't a guess from a
/// numbered label. The selection writes straight to the app-wide store.
struct SilhouettePickerView: View {
    @AppStorage(BodyType.storageKey) private var bodyTypeRaw = BodyType.neutral.rawValue

    var body: some View {
        List {
            Section {
                ForEach(BodyType.allCases) { type in
                    Button {
                        bodyTypeRaw = type.rawValue
                    } label: {
                        row(for: type)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("silhouetteOption-\(type.rawValue)")
                }
            } footer: {
                Text("The same figure is used on the body map and every site preview.")
            }
        }
        .navigationTitle("Silhouette")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for type: BodyType) -> some View {
        let isSelected = bodyTypeRaw == type.rawValue
        return HStack(spacing: 16) {
            Image(type.assetName(for: .front))
                .resizable()
                .scaledToFit()
                .opacity(AppTheme.silhouetteOpacity)
                .frame(width: 48, height: 96)
                .accessibilityHidden(true)
            Text("Silhouette \(type.displayName)")
                .font(.body)
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? AppTheme.accent : Color(.tertiaryLabel))
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Silhouette \(type.displayName)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Per-track region toggles. Excluding a region drops its sites from that
/// track's suggestions and body map; the last enabled region can't be turned
/// off, since a track with no regions has nothing to rotate through.
struct RegionSettingsView: View {
    let device: DeviceType
    @AppStorage private var disabledRaw: String

    init(device: DeviceType) {
        self.device = device
        self._disabledRaw = AppStorage(wrappedValue: "", RegionSettings.storageKey(for: device))
    }

    var body: some View {
        let disabled = RegionSettings.parse(disabledRaw)
        List {
            Section {
                ForEach(PumpSite.Region.allCases) { region in
                    Button {
                        toggle(region)
                    } label: {
                        row(for: region, isOn: !disabled.contains(region))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("regionOption-\(region.rawValue)")
                }
            } footer: {
                Text("Tap to include or exclude a region for your \(device.noun). Excluded regions are greyed out and won't be suggested or shown on the body map for this track. Records already on those sites are kept.")
            }
        }
        .navigationTitle("\(device.displayName) areas")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A checklist row in the silhouette-picker style: an included region shows
    /// a filled checkmark in the track's tint; an excluded one greys out with
    /// an empty circle.
    private func row(for region: PumpSite.Region, isOn: Bool) -> some View {
        HStack {
            Text(region.displayName)
                .foregroundStyle(isOn ? .primary : .secondary)
            Spacer()
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isOn ? AppTheme.tint(for: device) : Color(.tertiaryLabel))
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(region.displayName)
        .accessibilityValue(isOn ? "Included" : "Excluded")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private func toggle(_ region: PumpSite.Region) {
        var disabled = RegionSettings.parse(disabledRaw)
        if disabled.contains(region) {
            disabled.remove(region)
        } else {
            // Keep at least one region enabled — a track with none has nothing
            // to rotate through.
            guard disabled.count < PumpSite.Region.allCases.count - 1 else { return }
            disabled.insert(region)
        }
        disabledRaw = RegionSettings.encode(disabled)
    }
}

#Preview("Settings") {
    SettingsView()
}

#Preview("Region settings") {
    NavigationStack {
        RegionSettingsView(device: .cgm)
    }
}

#Preview("Silhouette picker") {
    NavigationStack {
        SilhouettePickerView()
    }
}

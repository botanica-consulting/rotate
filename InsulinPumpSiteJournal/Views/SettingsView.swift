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
    @AppStorage(AreaSettings.storageKey(for: .pump)) private var pumpDisabledSites = ""
    @AppStorage(AreaSettings.storageKey(for: .cgm)) private var sensorDisabledSites = ""
    @State private var confirmingReset = false
    /// Typed reset confirmation — the journal now syncs, so a reset reaches
    /// every device. Deleting requires typing RESET, not just a second tap.
    @State private var resetConfirmationText = ""
    @State private var resetError: Error?

    var body: some View {
        NavigationStack {
            Form {
                silhouetteSection
                deviceSection(for: .pump, companion: $pumpCompanionRaw, disabledRaw: pumpDisabledSites)
                deviceSection(for: .cgm, companion: $sensorCompanionRaw, disabledRaw: sensorDisabledSites)
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

    /// Everything specific to one track — its companion app and its rotation
    /// areas — collected under a single header, so the pump's settings and the
    /// sensor's settings each live in one place instead of being spread across
    /// the screen.
    @ViewBuilder
    private func deviceSection(
        for device: DeviceType,
        companion: Binding<String>,
        disabledRaw: String
    ) -> some View {
        Section {
            Picker("Companion app", selection: companion) {
                ForEach(CompanionApp.options(for: device)) { app in
                    Text(app.displayName).tag(app.rawValue)
                }
            }
            .accessibilityIdentifier(device == .pump ? "pumpCompanionPicker" : "sensorCompanionPicker")
            areaLink(for: device, disabledRaw: disabledRaw)
        } header: {
            Text(device.displayName)
        } footer: {
            Text("Confirming a \(device.noun) placement opens its companion app to activate and pair — choose None to stay in Rotate. Rotation areas set where new \(device.noun) sites can be suggested.")
        }
    }

    private func areaLink(for device: DeviceType, disabledRaw: String) -> some View {
        let total = PumpSite.catalog.count
        let enabled = total - AreaSettings.parse(disabledRaw).count
        return NavigationLink {
            AreaSettingsView(device: device)
        } label: {
            HStack {
                Text("Rotation areas")
                Spacer()
                Text(enabled == total ? "All areas" : "\(enabled) of \(total)")
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier(device == .pump ? "pumpRegionsLink" : "sensorRegionsLink")
        .accessibilityLabel("\(device.displayName) rotation areas, \(enabled) of \(total) on")
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

/// Per-track area picker. Mirrors the choose-a-site screen: a grid of body
/// figures with each area highlighted, grouped by region, so you pick by sight
/// rather than by label. Tapping an area includes or excludes it for this
/// track — excluded areas grey out and drop from the track's suggestions and
/// body map. The last enabled area can't be turned off, since a track with no
/// areas has nothing to rotate through. Records already on an excluded area are
/// kept.
struct AreaSettingsView: View {
    let device: DeviceType
    @AppStorage private var disabledRaw: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(device: DeviceType) {
        self.device = device
        self._disabledRaw = AppStorage(wrappedValue: "", AreaSettings.storageKey(for: device))
    }

    /// One column at accessibility text sizes so cards never cram — the same
    /// rule the choose-a-site grid uses.
    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
    }

    var body: some View {
        let disabled = AreaSettings.parse(disabledRaw)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Tap an area to include or exclude it for your \(device.noun). Excluded areas grey out and won't be suggested or shown on the body map for this track.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 4)

                ForEach(PumpSite.Region.allCases) { region in
                    let sites = PumpSite.catalog.filter { $0.region == region }
                    if !sites.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(region.displayName)
                                .font(.headline)
                                .padding(.horizontal)
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(sites) { site in
                                    AreaToggleCard(
                                        site: site,
                                        device: device,
                                        isOn: !disabled.contains(site.id)
                                    ) {
                                        toggle(site.id)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(AppBackground())
        .navigationTitle("\(device.displayName) areas")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ id: String) {
        var disabled = AreaSettings.parse(disabledRaw)
        if disabled.contains(id) {
            disabled.remove(id)
        } else {
            // Keep at least one area enabled — a track with none has nothing
            // to rotate through.
            guard disabled.count < PumpSite.catalog.count - 1 else { return }
            disabled.insert(id)
        }
        disabledRaw = AreaSettings.encode(disabled)
    }
}

/// A single area card in the picker: the choose-a-site card, reduced to what a
/// setting needs. An included area lights its highlight in the track's tint and
/// carries a filled checkmark; an excluded one desaturates and dims with an
/// empty circle, so inclusion reads at a glance without relying on color alone.
private struct AreaToggleCard: View {
    let site: PumpSite
    let device: DeviceType
    let isOn: Bool
    let action: () -> Void

    private let thumbnailHeight: CGFloat = 120
    /// The same resting zoom the unselected choose-a-site cards use, so the
    /// figure keeps body context while emphasizing the area.
    private let restingZoom: CGFloat = 1.35

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                BodyThumbnail(
                    site: site,
                    fill: isOn ? AppTheme.tint(for: device) : Color(.systemGray3),
                    zoom: restingZoom
                )
                .frame(height: thumbnailHeight)
                .frame(maxWidth: .infinity)
                .clipped()
                // Excluded areas drop their color entirely, not just dim it, so
                // the off state doesn't read as a faint tint.
                .saturation(isOn ? 1 : 0)

                Text(site.bodyView == .front ? "Front" : "Rear")
                    .font(.caption2.smallCaps())
                    .foregroundStyle(.secondary)
                Text(site.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isOn ? .primary : .secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .overlay(alignment: .topTrailing) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? AppTheme.tint(for: device) : Color(.tertiaryLabel))
                    .padding(8)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect(cornerRadius: AppTheme.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(.thinMaterial)
        }
        // Dim the whole excluded card so it recedes behind the included ones.
        .opacity(isOn ? 1 : 0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(site.title)
        .accessibilityValue(isOn ? "Included" : "Excluded")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("areaOption-\(site.id)")
    }
}

#Preview("Settings") {
    SettingsView()
}

#Preview("Area settings") {
    NavigationStack {
        AreaSettingsView(device: .cgm)
    }
}

#Preview("Silhouette picker") {
    NavigationStack {
        SilhouettePickerView()
    }
}

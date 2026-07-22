import SwiftUI
import SwiftData

/// App settings: the silhouette the body map renders, the companion app the
/// new-Pod flow hands off to, and the journal reset. Placement distances
/// always follow the device's measurement system, so there's no unit setting.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(CompanionApp.storageKey) private var companionRaw = CompanionApp.loop.rawValue
    @AppStorage(BodyType.storageKey) private var bodyTypeRaw = BodyType.neutral.rawValue
    @State private var confirmingReset = false
    /// Typed reset confirmation — the journal now syncs, so a reset reaches
    /// every device. Deleting requires typing RESET, not just a second tap.
    @State private var resetConfirmationText = ""
    @State private var resetError: Error?

    var body: some View {
        NavigationStack {
            Form {
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

                Section {
                    Picker("Continue in", selection: $companionRaw) {
                        ForEach(CompanionApp.allCases) { app in
                            Text(app.displayName).tag(app.rawValue)
                        }
                    }
                    .accessibilityIdentifier("companionAppPicker")
                } header: {
                    Text("Companion app")
                } footer: {
                    Text("Confirming a new placement opens this app to activate and pair it. Loop is the only companion supported for now.")
                }

                Section {
                    Button("Reset journal…", role: .destructive) {
                        confirmingReset = true
                    }
                    .accessibilityIdentifier("resetJournalButton")
                } footer: {
                    Text("Deletes every Pod record, here and from iCloud on your other devices. Settings are kept.")
                }

                Section {
                } footer: {
                    Text("Privacy: your journal is stored on this device and syncs through your private iCloud database, readable only by your Apple Account. No third-party servers are involved.")
                }
            }
            .alert(
                "Delete all Pod records?",
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

    private var selectedBodyType: BodyType {
        BodyType(rawValue: bodyTypeRaw) ?? .neutral
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

#Preview("Settings") {
    SettingsView()
}

#Preview("Silhouette picker") {
    NavigationStack {
        SilhouettePickerView()
    }
}

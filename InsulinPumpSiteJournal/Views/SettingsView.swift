import SwiftUI
import SwiftData

/// App settings: measurement units for placement guidance, the companion
/// app the new-Pod flow hands off to, and the journal reset. The silhouette
/// picker lives on the body map, next to the figures it changes.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(MeasurementUnit.storageKey) private var unitRaw = MeasurementUnit.system.rawValue
    @AppStorage(CompanionApp.storageKey) private var companionRaw = CompanionApp.loop.rawValue
    @State private var confirmingReset = false
    /// Typed reset confirmation — the journal now syncs, so a reset reaches
    /// every device. Deleting requires typing RESET, not just a second tap.
    @State private var resetConfirmationText = ""
    @State private var resetError: Error?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Distances", selection: $unitRaw) {
                        ForEach(MeasurementUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit.rawValue)
                        }
                    }
                    .accessibilityIdentifier("unitPicker")
                } header: {
                    Text("Units")
                } footer: {
                    Text("Used for placement guidance, like the minimum distance from your previous site.")
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
                    Text("Confirming a new Pod opens this app to activate and pair it. Loop is the only companion supported for now.")
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

    private func resetJournal() {
        do {
            try JournalStore(context: modelContext).reset()
            dismiss()
        } catch {
            resetError = error
        }
    }
}

#Preview("Settings") {
    SettingsView()
}

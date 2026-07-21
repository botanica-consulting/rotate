import SwiftUI
import SwiftData

/// App settings: measurement units for placement guidance, and the journal
/// reset. The silhouette picker lives on the body map, next to the figures
/// it changes.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(MeasurementUnit.storageKey) private var unitRaw = MeasurementUnit.system.rawValue
    @State private var confirmingReset = false
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
                    Button("Reset journal…", role: .destructive) {
                        confirmingReset = true
                    }
                    .accessibilityIdentifier("resetJournalButton")
                } footer: {
                    Text("Deletes every Pod record. Settings are kept.")
                }

                Section {
                } footer: {
                    Text("Privacy: your journal is stored only on this device. It leaves the device only through your encrypted device backup — iCloud sync is off.")
                }
            }
            .confirmationDialog(
                "Delete all Pod records?",
                isPresented: $confirmingReset,
                titleVisibility: .visible
            ) {
                Button("Delete all records", role: .destructive) {
                    resetJournal()
                }
                .accessibilityIdentifier("confirmResetButton")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes your entire placement history. It can't be undone.")
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

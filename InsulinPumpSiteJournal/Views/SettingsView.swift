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
        // Delete through fetched instances (not the batch API) so the home
        // screen's @Query observes the change immediately.
        let records = (try? modelContext.fetch(FetchDescriptor<PlacementRecord>())) ?? []
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview("Settings") {
    SettingsView()
}

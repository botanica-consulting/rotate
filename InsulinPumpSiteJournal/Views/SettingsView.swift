import SwiftUI

/// App settings: measurement units for placement guidance and the body type
/// used by the silhouettes. Stored in AppStorage — no model changes.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(MeasurementUnit.storageKey) private var unitRaw = MeasurementUnit.system.rawValue
    @AppStorage(BodyType.storageKey) private var bodyTypeRaw = BodyType.neutral.rawValue

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
                    Picker("Silhouette", selection: $bodyTypeRaw) {
                        ForEach(BodyType.allCases) { type in
                            Text(type.displayName).tag(type.rawValue)
                        }
                    }
                    .accessibilityIdentifier("settingsBodyTypePicker")
                } header: {
                    Text("Body type")
                } footer: {
                    Text("Sets the figure shown on suggestion cards and the body map.")
                }
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
}

#Preview("Settings") {
    SettingsView()
}

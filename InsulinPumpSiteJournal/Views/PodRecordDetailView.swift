import SwiftUI
import SwiftData

/// One Pod's journal record: where it sat, when it went on and came off, and
/// free-form notes ("leaked", "fell off early", …). Presented as a sheet from
/// the current-Pod card and from history rows.
struct PodRecordDetailView: View {
    @Bindable var record: PlacementRecord
    /// Stop time to display — the caller resolves stamped vs. inferred stops;
    /// nil means the Pod is still on.
    let stop: Date?
    /// Called when the user asks to delete; the caller performs the delete
    /// after this sheet has dismissed.
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var confirmingDelete = false
    @State private var saveError: Error?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        if let site {
                            VignettedBodyThumbnail(site: site, fill: AppTheme.recent)
                                .frame(width: 80, height: 80)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(siteTitle)
                                .font(.headline)
                            if stop == nil {
                                PodAgeCounter(placedAt: record.placedAt)
                            }
                        }
                        Spacer()
                    }
                }

                Section("Timing") {
                    LabeledContent("On", value: formatted(record.placedAt))
                    LabeledContent("Off", value: stop.map(formatted) ?? "Still on")
                    if let stop {
                        LabeledContent("Worn") {
                            Text(PodAgeCounter.text(at: stop, since: record.placedAt))
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }

                Section("Notes") {
                    TextField(
                        "Leaked, irritated skin, fell off early…",
                        text: $record.notes,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .accessibilityIdentifier("notesField")
                }

                Section {
                    Button("Delete record…", role: .destructive) {
                        confirmingDelete = true
                    }
                    .accessibilityIdentifier("deleteRecordButton")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(siteTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .accessibilityIdentifier("closeRecordButton")
                }
            }
            .confirmationDialog(
                "Delete this record?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                .accessibilityIdentifier("confirmDeleteRecordButton")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes the \(siteTitle) placement and its notes.")
            }
            .alert(
                "Couldn't save your note",
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                ),
                presenting: saveError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.localizedDescription)
            }
            .onDisappear {
                // Fallback for swipe-dismiss; Done already saved (or alerted).
                try? modelContext.save()
            }
        }
        .presentationDetents([.medium, .large])
        .fontDesign(.rounded)
    }

    private func saveAndDismiss() {
        do {
            try JournalStore(context: modelContext).save()
            dismiss()
        } catch {
            saveError = error
        }
    }

    private var site: PumpSite? {
        PumpSite.site(for: record.siteID)
    }

    private var siteTitle: String {
        site?.title ?? record.siteID
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

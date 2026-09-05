import SwiftUI
import SwiftData

/// One Pod's journal record: where it sat, when it went on and came off, and
/// free-form notes ("leaked", "fell off early", …). Presented as a sheet from
/// the current-Pod card and from history rows.
///
/// Times are editable after the fact — you notice in the morning that you
/// actually changed the site the night before. The pickers are limited to the
/// gap between the neighbouring placements (`PlacementTimeline.TimingBounds`),
/// so an edit can never reorder history, and `JournalStore.updateTiming`
/// re-checks the same limits on save.
struct PodRecordDetailView: View {
    @Bindable var record: PlacementRecord
    /// Stop time to display — the caller resolves stamped vs. inferred stops;
    /// nil means the Pod is still on.
    let stop: Date?
    /// How far the times may move, from the caller's per-track timeline.
    let bounds: PlacementTimeline.TimingBounds
    /// Called when the user asks to delete; the caller performs the delete
    /// after this sheet has dismissed.
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var confirmingDelete = false
    @State private var saveError: Error?

    /// Draft times. Edits are held here, not written straight through the
    /// `@Bindable` record, so an out-of-range value is never stored and never
    /// has to be rolled back out of the object graph.
    @State private var draftPlacedAt = Date.now
    @State private var draftRemovedAt: Date?
    @State private var didLoadDraft = false

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
                            DeviceChip(device: device)
                            Text(siteTitle)
                                .font(.headline)
                            if draftRemovedAt == nil && stop == nil {
                                PodAgeCounter(placedAt: draftPlacedAt, tint: AppTheme.tint(for: device))
                            }
                        }
                        Spacer()
                    }
                }

                timingSection

                Section("Notes") {
                    TextField(
                        device.notesPlaceholder,
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
                "Couldn't save your changes",
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
            .task {
                loadDraftIfNeeded()
            }
            .onDisappear {
                persistOnDismiss()
            }
        }
        .presentationDetents([.medium, .large])
        .fontDesign(.rounded)
    }

    // MARK: - Timing

    /// "On" is always editable. "Off" has three states: a stamped stop edits
    /// directly; an *inferred* stop (nil `removedAt`, resolved by the timeline
    /// from the next placement) is shown as-is until the user chooses to pin it,
    /// which stamps it; and a placement still on the body has no stop to edit.
    @ViewBuilder
    private var timingSection: some View {
        Section {
            DatePicker(
                "On",
                selection: $draftPlacedAt,
                in: bounds.placedAtRange,
                displayedComponents: [.date, .hourAndMinute]
            )
            .accessibilityIdentifier("onDatePicker")

            if draftRemovedAt != nil {
                DatePicker(
                    "Off",
                    selection: removedAtBinding,
                    in: bounds.removedAtRange(placedAt: draftPlacedAt),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .accessibilityIdentifier("offDatePicker")

                if isNewestInTrack {
                    Button("Still on — clear removal time") {
                        draftRemovedAt = nil
                    }
                    .accessibilityIdentifier("clearRemovalButton")
                }
            } else if let stop {
                LabeledContent("Off", value: formatted(stop))
                Button("Set removal time…") {
                    draftRemovedAt = stop
                }
                .accessibilityIdentifier("stampRemovalButton")
            } else {
                LabeledContent("Off", value: "Still on")
            }

            if let worn = draftRemovedAt ?? stop {
                LabeledContent("Worn") {
                    Text(PodAgeCounter.text(at: worn, since: draftPlacedAt))
                        .font(.system(.body, design: .monospaced))
                }
            }
        } header: {
            Text("Timing")
        } footer: {
            if draftRemovedAt == nil, stop != nil {
                Text("This time is worked out from the next placement. Pin it if you know when the \(device.noun) actually came off.")
            }
        }
    }

    private var removedAtBinding: Binding<Date> {
        Binding(
            get: { draftRemovedAt ?? stop ?? draftPlacedAt },
            set: { draftRemovedAt = $0 }
        )
    }

    /// Whether this is the latest placement on its track — the only one that
    /// can be reopened, since a track holds at most one placement still on.
    private var isNewestInTrack: Bool { bounds.nextPlacedAt == nil }

    private func loadDraftIfNeeded() {
        guard !didLoadDraft else { return }
        didLoadDraft = true
        draftPlacedAt = record.placedAt
        draftRemovedAt = record.removedAt
    }

    // MARK: - Saving

    private func saveAndDismiss() {
        do {
            try JournalStore(context: modelContext).updateTiming(
                record,
                placedAt: draftPlacedAt,
                removedAt: draftRemovedAt
            )
            dismiss()
        } catch {
            saveError = error
        }
    }

    /// Fallback for swipe-dismiss; Done already saved (or alerted). If the draft
    /// times don't validate they're dropped rather than stored, and the notes
    /// edit is still persisted on its own.
    private func persistOnDismiss() {
        guard didLoadDraft else { return }
        let store = JournalStore(context: modelContext)
        do {
            try store.updateTiming(record, placedAt: draftPlacedAt, removedAt: draftRemovedAt)
        } catch {
            try? store.save()
        }
    }

    private var device: DeviceType {
        DeviceType(rawValue: record.deviceType) ?? .pump
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

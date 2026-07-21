import SwiftUI
import SwiftData

/// Root view: a full-screen card for the Pod that's on now, with the journal
/// history one page-swipe up. History content stays on plain, high-contrast
/// surfaces — Liquid Glass is reserved for the New Pod button. Layout and
/// user intent only: lifecycle rules live in PlacementTimeline/JournalStore.
struct HistoryHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlacementRecord.placedAt, order: .reverse)
    private var records: [PlacementRecord]

    @State private var showingNewPod = false
    @State private var showingBodyMap = false
    @State private var showingSettings = false
    @State private var selectedRecord: PlacementRecord?
    /// Deletion requested from the detail sheet; performed after it dismisses
    /// so the sheet never animates out holding a deleted model.
    @State private var pendingDelete: PlacementRecord?
    @State private var storeError: Error?
    /// Live scroll offset for the paging behavior — a reference box, not
    /// invalidating @State, so tracking it doesn't re-render every frame.
    @State private var scrollOffset = ScrollOffsetBox()

    private var timeline: PlacementTimeline {
        PlacementTimeline(records: records)
    }

    var body: some View {
        NavigationStack {
            // The New Pod button sits below the scroll area (not floating
            // over it), so the history page never peeks out around it.
            VStack(spacing: 0) {
                if records.isEmpty {
                    emptyState
                } else {
                    pagedContent
                }
                newPodButton
            }
            .background(AppBackground())
            .navigationTitle("Sites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("settingsButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingBodyMap = true
                    } label: {
                        Label("Body map", systemImage: "figure.stand")
                    }
                    .accessibilityIdentifier("bodyMapButton")
                }
            }
            .fullScreenCover(isPresented: $showingNewPod) {
                NewPodFlowView()
            }
            .sheet(isPresented: $showingBodyMap) {
                BodyMapView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $selectedRecord, onDismiss: performPendingDelete) { record in
                PodRecordDetailView(
                    record: record,
                    stop: timeline.entries.first { $0.id == record.id }?.stop,
                    onDelete: { pendingDelete = record }
                )
            }
            .alert(
                "Couldn't update your journal",
                isPresented: Binding(
                    get: { storeError != nil },
                    set: { if !$0 { storeError = nil } }
                ),
                presenting: storeError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.localizedDescription)
            }
        }
        .fontDesign(.rounded)
    }

    private var newPodButton: some View {
        Button {
            showingNewPod = true
        } label: {
            Label("New Pod", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(AppTheme.accent)
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .accessibilityIdentifier("newPodButton")
    }

    private var emptyState: some View {
        VStack {
            ContentUnavailableView {
                Label("No placements yet", systemImage: "figure.arms.open")
            } description: {
                Text("Tap New Pod to record your first site.")
            }
            safetyFooter
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Paged layout

    /// Page one fills the screen with the current Pod; scrolling up snaps
    /// onto the history page.
    private var pagedContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    heroPage(proxy: proxy)
                        .containerRelativeFrame(.vertical)
                    historyPage
                        .id("historyPage")
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                scrollOffset.value = offset
            }
            .scrollTargetBehavior(HeroPagingBehavior(currentOffset: scrollOffset))
            .scrollIndicators(.hidden)
        }
    }

    private func heroPage(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Current")
            if let current = timeline.current {
                currentPodCard(for: current)
            } else {
                noPodCard
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    proxy.scrollTo("historyPage", anchor: .top)
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "chevron.compact.up")
                    Text("History")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show history")
            .accessibilityIdentifier("historyHintButton")
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func currentPodCard(for entry: PlacementTimeline.Entry) -> some View {
        Button {
            selectedRecord = entry.record
        } label: {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(siteTitle(for: entry))
                        .font(.title3.weight(.semibold))
                    Text("Placed \(entry.placedAt.formatted(.relative(presentation: .named)))")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.recent)
                    PodAgeCounter(placedAt: entry.placedAt)
                        .padding(.top, 10)
                }
                Spacer()
                if let site = PumpSite.site(for: entry.siteID) {
                    VignettedBodyThumbnail(site: site, fill: AppTheme.recent)
                        .frame(width: 96, height: 96)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(.thinMaterial)
            )
            .contentShape(.rect(cornerRadius: AppTheme.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            "Current site: \(siteTitle(for: entry)), on for \(PodAgeCounter.spokenText(at: .now, since: entry.placedAt)), placed \(absoluteDate(entry.placedAt))"
        )
        .accessibilityHint("Opens this Pod's record to review times or add notes.")
        .accessibilityIdentifier("currentPodCard")
    }

    /// The valid in-between state: history exists, but the newest Pod has a
    /// removal time and nothing has replaced it yet.
    private var noPodCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No Pod on")
                .font(.title3.weight(.semibold))
            if let last = timeline.entries.first, let stop = last.stop {
                Text("Last site: \(siteTitle(for: last)), removed \(absoluteDate(stop))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Tap New Pod when you place your next one.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(.thinMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("noPodCard")
    }

    private var historyPage: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("History")

            LazyVStack(spacing: 0) {
                let entries = timeline.entries
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    historyRow(for: entry, index: index)
                    if index < entries.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(.thinMaterial)
            )

            averagePodLife
        }
        .padding(.horizontal)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private func historyRow(for entry: PlacementTimeline.Entry, index: Int) -> some View {
        Button {
            selectedRecord = entry.record
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(siteTitle(for: entry))
                            .font(.body.weight(.medium))
                        if !entry.record.notes.isEmpty {
                            Image(systemName: "note.text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(wearRangeText(for: entry))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let stop = entry.stop {
                    Text(PodAgeCounter.text(at: stop, since: entry.placedAt))
                        .font(.system(.subheadline, design: .monospaced).weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    PodAgeCounter(placedAt: entry.placedAt)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(rowAccessibilityLabel(for: entry))
        .accessibilityHint("Opens this record to review times or add notes.")
        .accessibilityIdentifier("historyRow-\(index)")
    }

    @ViewBuilder
    private var averagePodLife: some View {
        if let average = timeline.averageWear {
            let text = "\(Int((average / 3_600).rounded()))h"
            VStack(spacing: 2) {
                Text(text)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .foregroundStyle(AppTheme.glucose)
                Text("average Pod life")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Average Pod life: \(text.dropLast()) hours")
        }
    }

    // MARK: - Formatting

    private func wearRangeText(for entry: PlacementTimeline.Entry) -> String {
        let start = entry.placedAt.formatted(date: .abbreviated, time: .shortened)
        guard let stop = entry.stop else { return "On since \(start)" }
        return "\(start) – \(stop.formatted(date: .abbreviated, time: .shortened))"
    }

    private func rowAccessibilityLabel(for entry: PlacementTimeline.Entry) -> String {
        var parts = ["\(siteTitle(for: entry)), placed \(absoluteDate(entry.placedAt))"]
        if let stop = entry.stop {
            parts.append("removed \(absoluteDate(stop))")
            parts.append("worn \(PodAgeCounter.spokenText(at: stop, since: entry.placedAt))")
        } else {
            parts.append("on for \(PodAgeCounter.spokenText(at: .now, since: entry.placedAt))")
        }
        if !entry.record.notes.isEmpty {
            parts.append("note: \(entry.record.notes)")
        }
        return parts.joined(separator: ", ")
    }

    private var safetyFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Follow your Omnipod training. Avoid irritated or scarred skin and keep the required spacing between sites.")
            Link(
                "Omnipod placement guide",
                destination: URL(string: "https://www.omnipod.com/current-podders/resources/pod-placement-guide")!
            )
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func siteTitle(for entry: PlacementTimeline.Entry) -> String {
        PumpSite.site(for: entry.siteID)?.title ?? entry.siteID
    }

    private func absoluteDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func performPendingDelete() {
        guard let record = pendingDelete else { return }
        pendingDelete = nil
        do {
            // Deletion never reopens another Pod; if this was the current
            // one, the home shows the explicit "No Pod on" state.
            try JournalStore(context: modelContext).delete(record)
        } catch {
            storeError = error
        }
    }
}

/// Shared mutable scroll offset for HeroPagingBehavior.
final class ScrollOffsetBox {
    var value: CGFloat = 0
}

/// Snaps between the full-screen current-Pod page and the top of the history
/// page — the exact spot the History hint button scrolls to — deciding from
/// where the gesture started, so a swipe never over- or undershoots the page.
/// Once inside history, scrolling is free. When the history is shorter than
/// a screen the snap point falls back to the deepest reachable offset.
struct HeroPagingBehavior: ScrollTargetBehavior {
    let currentOffset: ScrollOffsetBox

    /// Projected travel past which a gesture counts as a page flick rather
    /// than a settle-back drag.
    static let flickTravel: CGFloat = 80

    /// Pure snap decision, separated for unit testing. Returns the offset to
    /// settle at, or nil to leave the scroll free (deep inside history).
    static func snapOffset(
        proposed: CGFloat,
        from: CGFloat,
        containerHeight: CGFloat,
        contentHeight: CGFloat
    ) -> CGFloat? {
        let maxOffset = max(0, contentHeight - containerHeight)
        let boundary = min(containerHeight, maxOffset)
        guard boundary > 0 else { return nil }

        if from < boundary - 1 {
            // Leaving the hero: land on the history page top on a real swipe
            // (projected travel) or a drag past halfway; otherwise settle back.
            let pastHalf = proposed > boundary / 2
            return (pastHalf || proposed - from > flickTravel) ? boundary : 0
        }
        if proposed < boundary - 1 {
            // Heading back down out of history: hero, or hold the page top.
            let pastHalf = proposed < boundary / 2
            return (pastHalf || from - proposed > flickTravel) ? 0 : boundary
        }
        return nil
    }

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        if let snapped = Self.snapOffset(
            proposed: target.rect.minY,
            from: currentOffset.value,
            containerHeight: context.containerSize.height,
            contentHeight: context.contentSize.height
        ) {
            target.rect.origin.y = snapped
        }
    }
}

#Preview("Home") {
    HistoryHomeView()
        .modelContainer(for: PlacementRecord.self, inMemory: true)
}

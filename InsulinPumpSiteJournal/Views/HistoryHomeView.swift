import SwiftUI
import SwiftData

/// Root view: a full-screen card for the Pod that's on now, with the journal
/// history one page-swipe up. History content stays on plain, high-contrast
/// surfaces — Liquid Glass is reserved for the New Pod button.
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
    /// Live scroll offset for the paging behavior — a reference box, not
    /// invalidating @State, so tracking it doesn't re-render every frame.
    @State private var scrollOffset = ScrollOffsetBox()

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
                    stop: stopDate(for: record),
                    onDelete: { pendingDelete = record }
                )
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
            if let current = records.first {
                currentPodCard(for: current)
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

    private func currentPodCard(for record: PlacementRecord) -> some View {
        Button {
            selectedRecord = record
        } label: {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(siteTitle(for: record))
                        .font(.title3.weight(.semibold))
                    Text("Placed \(record.placedAt.formatted(.relative(presentation: .named)))")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.recent)
                    PodAgeCounter(placedAt: record.placedAt)
                        .padding(.top, 10)
                }
                Spacer()
                if let site = PumpSite.site(for: record.siteID) {
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
            "Current site: \(siteTitle(for: record)), on for \(PodAgeCounter.spokenText(at: .now, since: record.placedAt)), placed \(absoluteDate(record.placedAt))"
        )
        .accessibilityHint("Opens this Pod's record to review times or add notes.")
        .accessibilityIdentifier("currentPodCard")
    }

    private var historyPage: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("History")

            // Deliberately not lazy: histories stay small (a Pod every ~3
            // days) and eager rows keep the full journal reachable by
            // VoiceOver and UI tests without scrolling games.
            VStack(spacing: 0) {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    historyRow(for: record, index: index)
                    if index < records.count - 1 {
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

    private func historyRow(for record: PlacementRecord, index: Int) -> some View {
        let stop = stopDate(for: record)
        return Button {
            selectedRecord = record
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(siteTitle(for: record))
                            .font(.body.weight(.medium))
                        if !record.notes.isEmpty {
                            Image(systemName: "note.text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(wearRangeText(for: record, stop: stop))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let stop {
                    Text(PodAgeCounter.text(at: stop, since: record.placedAt))
                        .font(.system(.subheadline, design: .monospaced).weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    PodAgeCounter(placedAt: record.placedAt)
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
        .accessibilityLabel(rowAccessibilityLabel(for: record, stop: stop))
        .accessibilityHint("Opens this record to review times or add notes.")
        .accessibilityIdentifier("historyRow-\(index)")
    }

    @ViewBuilder
    private var averagePodLife: some View {
        if let text = averagePodLifeText {
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

    // MARK: - Record math

    /// Stop time for a record: the stamped removal, or — for records saved
    /// before stop tracking existed — the next placement's start. Nil means
    /// the Pod is still on.
    private func stopDate(for record: PlacementRecord) -> Date? {
        if let removedAt = record.removedAt {
            return removedAt
        }
        guard let index = records.firstIndex(where: { $0.id == record.id }), index > 0 else {
            return nil
        }
        return records[index - 1].placedAt
    }

    private var averagePodLifeText: String? {
        let durations = records.compactMap { record in
            stopDate(for: record).map { max(0, $0.timeIntervalSince(record.placedAt)) }
        }
        guard !durations.isEmpty else { return nil }
        let average = durations.reduce(0, +) / Double(durations.count)
        return "\(Int((average / 3_600).rounded()))h"
    }

    private func wearRangeText(for record: PlacementRecord, stop: Date?) -> String {
        let start = record.placedAt.formatted(date: .abbreviated, time: .shortened)
        guard let stop else { return "On since \(start)" }
        return "\(start) – \(stop.formatted(date: .abbreviated, time: .shortened))"
    }

    private func rowAccessibilityLabel(for record: PlacementRecord, stop: Date?) -> String {
        var parts = ["\(siteTitle(for: record)), placed \(absoluteDate(record.placedAt))"]
        if let stop {
            parts.append("removed \(absoluteDate(stop))")
            parts.append("worn \(PodAgeCounter.spokenText(at: stop, since: record.placedAt))")
        } else {
            parts.append("on for \(PodAgeCounter.spokenText(at: .now, since: record.placedAt))")
        }
        if !record.notes.isEmpty {
            parts.append("note: \(record.notes)")
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

    private func siteTitle(for record: PlacementRecord) -> String {
        PumpSite.site(for: record.siteID)?.title ?? record.siteID
    }

    private func absoluteDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func performPendingDelete() {
        guard let record = pendingDelete else { return }
        pendingDelete = nil
        let wasCurrent = records.first?.id == record.id
        let previous = records.dropFirst().first
        modelContext.delete(record)
        // Deleting the current Pod's record reopens the previous wear, so the
        // hero card keeps pointing at a Pod that is actually on.
        if wasCurrent {
            previous?.removedAt = nil
        }
        try? modelContext.save()
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
private struct HeroPagingBehavior: ScrollTargetBehavior {
    let currentOffset: ScrollOffsetBox

    /// Projected travel past which a gesture counts as a page flick rather
    /// than a settle-back drag.
    private static let flickTravel: CGFloat = 80

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let pageHeight = context.containerSize.height
        let maxOffset = max(0, context.contentSize.height - pageHeight)
        let boundary = min(pageHeight, maxOffset)
        guard boundary > 0 else { return }
        let from = currentOffset.value

        if from < boundary - 1 {
            // Leaving the hero: land on the history page top on a real swipe
            // (projected travel) or a drag past halfway; otherwise settle back.
            let projectedTravel = target.rect.minY - from
            let pastHalf = target.rect.minY > boundary / 2
            target.rect.origin.y = (pastHalf || projectedTravel > Self.flickTravel) ? boundary : 0
        } else if target.rect.minY < boundary - 1 {
            // Heading back down out of history: hero, or hold the page top.
            let projectedTravel = from - target.rect.minY
            let pastHalf = target.rect.minY < boundary / 2
            target.rect.origin.y = (pastHalf || projectedTravel > Self.flickTravel) ? 0 : boundary
        }
    }
}

#Preview("Home") {
    HistoryHomeView()
        .modelContainer(for: PlacementRecord.self, inMemory: true)
}

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

    /// Non-nil while the new-placement flow is open, carrying which track to
    /// record.
    @State private var pendingNewDevice: DeviceType?
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

    /// Unified timeline (both tracks) driving the shared history list.
    private var timeline: PlacementTimeline {
        PlacementTimeline(records: records)
    }

    /// Per-track timelines driving the two current cards and the per-device
    /// wear stats.
    private func timeline(for device: DeviceType) -> PlacementTimeline {
        PlacementTimeline(records: records, deviceType: device)
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
                newPlacementButtons
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
            .fullScreenCover(item: $pendingNewDevice) { device in
                NewPodFlowView(deviceType: device)
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

    /// Both tracks are always one tap away — placing a new Pod and a new
    /// sensor are independent actions, mirrored side by side.
    private var newPlacementButtons: some View {
        HStack(spacing: 12) {
            newButton(for: .pump)
            newButton(for: .cgm)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func newButton(for device: DeviceType) -> some View {
        Button {
            pendingNewDevice = device
        } label: {
            Label(device.newActionTitle, systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(AppTheme.accent)
        .controlSize(.large)
        .accessibilityIdentifier(device == .pump ? "newPodButton" : "newSensorButton")
    }

    private var emptyState: some View {
        VStack {
            ContentUnavailableView {
                Label("No placements yet", systemImage: "figure.arms.open")
            } description: {
                Text("Tap New Pod or New Sensor to record your first site.")
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
            deviceCard(for: .pump)
            deviceCard(for: .cgm)
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

    /// One track's current card: the placement in use now, or the explicit
    /// "nothing on" state that invites placing one.
    @ViewBuilder
    private func deviceCard(for device: DeviceType) -> some View {
        let track = timeline(for: device)
        if let current = track.current {
            currentCard(for: current, device: device)
        } else {
            noDeviceCard(for: device, timeline: track)
        }
    }

    private func currentCard(for entry: PlacementTimeline.Entry, device: DeviceType) -> some View {
        Button {
            selectedRecord = entry.record
        } label: {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    DeviceChip(device: device)
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
            "Current \(device.displayName.lowercased()) site: \(siteTitle(for: entry)), on for \(PodAgeCounter.spokenText(at: .now, since: entry.placedAt)), placed \(absoluteDate(entry.placedAt))"
        )
        .accessibilityHint("Opens this \(device.noun)'s record to review times or add notes.")
        .accessibilityIdentifier(device == .pump ? "currentPodCard" : "currentSensorCard")
    }

    /// The "nothing on" state for a track: either history exists but the newest
    /// placement has come off, or this track has never been used. Tapping it
    /// starts a new placement for that device.
    private func noDeviceCard(for device: DeviceType, timeline: PlacementTimeline) -> some View {
        Button {
            pendingNewDevice = device
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                DeviceChip(device: device)
                Text("No \(device.noun) on")
                    .font(.title3.weight(.semibold))
                if let last = timeline.entries.first, let stop = last.stop {
                    Text("Last site: \(siteTitle(for: last)), removed \(absoluteDate(stop))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Tap to place your next one.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(.thinMaterial)
            )
            .contentShape(.rect(cornerRadius: AppTheme.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Starts a new \(device.noun) placement.")
        .accessibilityIdentifier(device == .pump ? "noPodCard" : "noSensorCard")
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
                        DeviceChip(device: entry.deviceType)
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

    /// Average wear per track — the two verticals don't share a timeline, so
    /// their averages are reported separately.
    @ViewBuilder
    private var averagePodLife: some View {
        let stats = DeviceType.allCases.compactMap { device -> (DeviceType, TimeInterval)? in
            timeline(for: device).averageWear.map { (device, $0) }
        }
        if !stats.isEmpty {
            HStack(spacing: 32) {
                ForEach(stats, id: \.0) { device, average in
                    averageStat(for: device, average: average)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }

    private func averageStat(for device: DeviceType, average: TimeInterval) -> some View {
        let hours = Int((average / 3_600).rounded())
        return VStack(spacing: 2) {
            Text("\(hours)h")
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundStyle(AppTheme.glucose)
            Text("average \(device.noun) life")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Average \(device.noun) life: \(hours) hours")
    }

    // MARK: - Formatting

    private func wearRangeText(for entry: PlacementTimeline.Entry) -> String {
        let start = entry.placedAt.formatted(date: .abbreviated, time: .shortened)
        guard let stop = entry.stop else { return "On since \(start)" }
        return "\(start) – \(stop.formatted(date: .abbreviated, time: .shortened))"
    }

    private func rowAccessibilityLabel(for entry: PlacementTimeline.Entry) -> String {
        var parts = ["\(entry.deviceType.displayName), \(siteTitle(for: entry)), placed \(absoluteDate(entry.placedAt))"]
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

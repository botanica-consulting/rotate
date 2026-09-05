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
    /// Observed only to keep `CustomSiteStore`'s mirror current. The site
    /// catalog is read from static entry points with no model context, so the
    /// live query is refreshed into UserDefaults here — which also catches a
    /// custom site arriving from another device through CloudKit.
    @Query(sort: \CustomSite.createdAt, order: .forward)
    private var customSites: [CustomSite]

    /// Non-nil while the new-placement flow is open, carrying which track to
    /// record.
    @State private var pendingNewDevice: DeviceType?
    /// Requests arriving from outside the UI — a Siri shortcut or a widget tap.
    private var router = AppRouter.shared
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

    /// The shared history list: every track's entries merged newest-first,
    /// each with its stop resolved within its own track so both a currently-
    /// worn pump and sensor read as still on (not one closing the other).
    private var historyEntries: [PlacementTimeline.Entry] {
        PlacementTimeline.combinedEntries(records: records)
    }

    /// Changes worth republishing the widget snapshot for: which placement is
    /// current on either track, and where it sits.
    private var snapshotKey: [String] {
        DeviceType.allCases.map { device in
            guard let current = timeline(for: device).current else { return "\(device.rawValue):none" }
            return "\(device.rawValue):\(current.siteID):\(current.placedAt.timeIntervalSince1970)"
        }
    }

    /// Opens the new-placement flow if something outside the UI asked for it,
    /// then clears the request so it fires once.
    private func consumeRouterRequest() {
        guard let device = router.pendingNewDevice else { return }
        router.pendingNewDevice = nil
        pendingNewDevice = device
    }

    /// Changes worth rewriting the mirror for — a site added, renamed,
    /// archived, or restored.
    private var customSiteMirrorKey: [String] {
        customSites.map { "\($0.siteID)|\($0.name)|\($0.isArchived)" }
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
            .onChange(of: customSiteMirrorKey, initial: true) { _, _ in
                CustomSiteStore.refreshMirror(customSites)
            }
            // Keeps the widget's snapshot in step: one hook covers a new site, a
            // deletion, an edited time, and a change merged in from another
            // device through CloudKit.
            .onChange(of: snapshotKey, initial: true) { _, _ in
                SnapshotPublisher.refresh(from: records)
            }
            // A widget tap or Siri shortcut. Handled on appear as well as on
            // change, since a cold launch sets the request before this view
            // exists and there is no change to observe.
            .task { consumeRouterRequest() }
            .onChange(of: router.pendingNewDevice) { _, _ in
                consumeRouterRequest()
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
                    stop: historyEntries.first { $0.id == record.id }?.stop,
                    // Bounds come from the record's own track, so a time edit
                    // can only move within the gap around it.
                    bounds: timeline(for: DeviceType(rawValue: record.deviceType) ?? .pump)
                        .timingBounds(for: record),
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

    /// Both tracks are always one tap away, stacked so neither crowds the
    /// other: the pump — the more frequent placement — leads as the prominent
    /// action, the sensor sits just below on lighter glass.
    private var newPlacementButtons: some View {
        VStack(spacing: 12) {
            newButton(for: .pump)
            newButton(for: .cgm)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func newButton(for device: DeviceType) -> some View {
        let button = Button {
            pendingNewDevice = device
        } label: {
            Label(device.newActionTitle, systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .accessibilityIdentifier(device == .pump ? "newPodButton" : "newSensorButton")

        // The pump leads as the single prominent CTA; the sensor takes lighter
        // tinted glass — the sensor teal keeps it clearly visible in both light
        // and dark (plain glass washed out against the background) while still
        // reading as secondary to the solid pump button.
        if device == .pump {
            button
                .buttonStyle(.glassProminent)
                .tint(AppTheme.accent)
        } else {
            button
                .buttonStyle(.glass)
                .tint(AppTheme.tint(for: .cgm))
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No placements yet", systemImage: "figure.arms.open")
        } description: {
            Text("Tap New Pump or New Sensor to record your first site.")
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
                    // Recomputed each minute (and on return to foreground) so
                    // "Placed yesterday" stays current without relaunching.
                    TimelineView(.everyMinute) { _ in
                        Text("Placed \(entry.placedAt.formatted(.relative(presentation: .named)))")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.recent)
                    }
                    PodAgeCounter(placedAt: entry.placedAt, tint: AppTheme.tint(for: device))
                        .padding(.top, 10)
                }
                Spacer()
                if let site = PumpSite.site(for: entry.siteID) {
                    VignettedBodyThumbnail(site: site, fill: AppTheme.recent, device: device)
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
                let entries = historyEntries
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

            averageWearStats
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
                    PodAgeCounter(placedAt: entry.placedAt, tint: AppTheme.tint(for: entry.deviceType))
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
    /// their averages are reported separately. Both tracks that have any
    /// history are always shown side by side; a track shows "—" until one of
    /// its placements has finished, so the pump and sensor stay paired.
    @ViewBuilder
    private var averageWearStats: some View {
        let stats = DeviceType.allCases.compactMap { device -> (DeviceType, TimeInterval?)? in
            let track = timeline(for: device)
            return track.entries.isEmpty ? nil : (device, track.averageWear)
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

    private func averageStat(for device: DeviceType, average: TimeInterval?) -> some View {
        let hours = average.map { Int(($0 / 3_600).rounded()) }
        return VStack(spacing: 2) {
            Text(hours.map { "\($0)h" } ?? "—")
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundStyle(hours == nil ? Color.secondary : AppTheme.tint(for: device))
            Text("average \(device.noun.lowercased()) life")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hours.map { "Average \(device.noun.lowercased()) life: \($0) hours" }
            ?? "No average \(device.noun.lowercased()) life yet")
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

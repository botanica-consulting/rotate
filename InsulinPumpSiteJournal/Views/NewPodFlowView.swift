import SwiftUI
import SwiftData

/// The full-screen new-Pod flow. One view, state-driven: choosing (four
/// suggestion cards, then a confirmation control once a card is selected)
/// and the placement instructions. Nothing is written until the user
/// confirms the Pod is on — abandoning the flow leaves the journal
/// untouched.
struct NewPodFlowView: View {
    /// Which rotation track this flow records. Suggestions, the site catalog,
    /// the instructions, and the saved record are all scoped to it.
    var deviceType: DeviceType = .pump

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// How many suggestion cards a deal shows (also the engine's limit).
    private static let suggestionCount = 4

    @State private var suggestions: [PumpSite] = []
    @State private var lastUsedBySite: [String: Date] = [:]
    @State private var recency = SiteRecencyModel(history: [])
    @State private var shownSiteIDs: Set<String> = []
    /// When on, the grid shows every site for this track — including the
    /// heavily used ones the suggestion engine holds back — instead of the
    /// four-card deal. Shuffle is moot in this mode.
    @State private var showingAllSites = false
    /// Which device (if any) currently sits on each site, across both tracks.
    /// Occupied cards get that device's badge; the other track's current site
    /// is also excluded from this track's suggestions.
    @State private var occupiedByDevice: [String: DeviceType] = [:]
    /// The other device's current site — never offered here (you can't wear
    /// two devices on one spot). A hard exclusion, applied to every deal.
    @State private var crossTrackExcluded: Set<String> = []
    @State private var selectedSite: PumpSite?
    /// Site being placed on the instruction screen — not yet saved.
    @State private var pendingSite: PumpSite?
    @State private var savedCount = 0
    /// Bumps once per Shuffle so the haptic fires on shuffle only, not on the
    /// initial load.
    @State private var shuffleCount = 0
    /// Guards the single save so a fast double-tap can't record twice.
    @State private var isSaving = false
    @State private var saveError: Error?

    /// One column at accessibility text sizes so card content never crams.
    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
    }

    var body: some View {
        NavigationStack {
            choosingContent
                .background(AppBackground())
                // The full title ellipsizes at accessibility text sizes; fall
                // back to a shorter one there instead of truncating.
                .navigationTitle(
                    dynamicTypeSize.isAccessibilitySize ? "Next site" : "Choose your next site"
                )
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(selectionAnimation) {
                                showingAllSites.toggle()
                                selectedSite = nil
                            }
                        } label: {
                            Image(systemName: showingAllSites ? "square.grid.2x2.fill" : "square.grid.2x2")
                        }
                        .accessibilityLabel(showingAllSites ? "Show suggested sites" : "Show all sites")
                        .accessibilityHint("Shows every site, including recently used ones.")
                        .accessibilityIdentifier("showAllButton")
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            shuffle()
                        } label: {
                            Image(systemName: "shuffle")
                        }
                        // Shuffle only reshuffles the deal; with every site
                        // already shown there is nothing left to shuffle.
                        .disabled(showingAllSites)
                        .accessibilityLabel("Shuffle suggestions")
                        .accessibilityHint("Shows a different set of sites, including recently rested ones.")
                        .accessibilityIdentifier("shuffleButton")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close without saving")
                        .accessibilityIdentifier("closeFlowButton")
                    }
                }
                // Push the placement step so going back is a native pop (no
                // crossfade flash) with a system back button. The trailing X
                // here saves and returns to the app — like Continue, minus the
                // hand-off to the companion app.
                .navigationDestination(item: $pendingSite) { site in
                    LoopHandoffView(
                        site: site,
                        deviceType: deviceType,
                        onConfirm: { finishPlacement(site, openCompanion: true) }
                    )
                    .background(AppBackground())
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                finishPlacement(site, openCompanion: false)
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .accessibilityLabel("Save and return to the app")
                            .accessibilityIdentifier("savePlacementButton")
                        }
                    }
                }
        }
        .sensoryFeedback(.selection, trigger: selectedSite)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: shuffleCount)
        .sensoryFeedback(.success, trigger: savedCount) { _, newValue in
            newValue > 0
        }
        .alert(
            "Couldn't save",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            ),
            presenting: saveError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text("The placement was not recorded. \(error.localizedDescription)")
        }
        .task {
            loadSuggestionsIfNeeded()
        }
    }

    /// The cards to render: the full catalog for this track in show-all mode,
    /// otherwise the current suggested deal.
    private var displayedSites: [PumpSite] {
        showingAllSites ? PumpSite.sites(for: deviceType) : suggestions
    }

    private var choosingContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(displayedSites.enumerated()), id: \.element.id) { index, site in
                        SiteSuggestionCard(
                            site: site,
                            lastUsed: lastUsedBySite[site.id],
                            tier: recency.tier(for: site.id),
                            isSelected: selectedSite == site,
                            index: index,
                            occupiedBy: occupiedByDevice[site.id]
                        ) {
                            withAnimation(selectionAnimation) {
                                selectedSite = site
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            if let site = selectedSite {
                Button {
                    pendingSite = site
                } label: {
                    Text("Use \(site.shortTitle)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(AppTheme.accent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 12)
                .accessibilityIdentifier("confirmSiteButton")
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// Quick fade only — the morph/scale treatment read as sluggish when
    /// moving the selection between cards.
    private var selectionAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.15)
    }

    /// History for this device track only, newest first.
    private func fetchHistory() -> [PlacementRecord] {
        let all = (try? JournalStore(context: modelContext).history()) ?? []
        return all.filter { $0.deviceType == deviceType.rawValue }
    }

    private func loadSuggestionsIfNeeded() {
        guard suggestions.isEmpty else { return }
        let all = (try? JournalStore(context: modelContext).history()) ?? []

        // What's on the body right now, per track. Occupied sites get that
        // device's badge in the grid; the *other* track's current site is a
        // hard exclusion here so we never suggest a spot already in use.
        var occupied: [String: DeviceType] = [:]
        for device in DeviceType.allCases {
            if let current = PlacementTimeline(records: all, deviceType: device).current {
                occupied[current.siteID] = device
            }
        }
        occupiedByDevice = occupied
        crossTrackExcluded = Set(occupied.filter { $0.value != deviceType }.map(\.key))

        let history = all.filter { $0.deviceType == deviceType.rawValue }
        lastUsedBySite = PlacementTimeline(records: history).lastUsedBySite
        recency = SiteRecencyModel(history: history)
        suggestions = SiteSuggestionEngine().suggestions(
            from: PumpSite.sites(for: deviceType),
            history: history,
            limit: Self.suggestionCount,
            excluding: recency.veryRecentSiteIDs.union(crossTrackExcluded),
            starterSiteIDs: PumpSite.starterSiteIDs(for: deviceType)
        )
        shownSiteIDs = Set(suggestions.map(\.id))
    }

    /// Deals a fresh set: sites shown since the last reset are excluded, which
    /// pulls in progressively more recently rested sites. Normally the last
    /// three used sites are held back. When the unseen pool runs low — quickly,
    /// on a small track like CGM — the rotation restarts excluding the set
    /// currently on screen; and once even the non-recent pool is exhausted the
    /// recency guard is relaxed so shuffle surfaces the recently rested sites
    /// too. A shuffle changes the cards whenever any other site exists.
    private func shuffle() {
        let history = fetchHistory()
        let engine = SiteSuggestionEngine()
        let offLimits = recency.veryRecentSiteIDs
        let current = Set(suggestions.map(\.id))

        func deal(excluding excluded: Set<String>) -> [PumpSite] {
            engine.suggestions(
                from: PumpSite.sites(for: deviceType),
                history: history,
                limit: Self.suggestionCount,
                // The other device's current site stays excluded even in the
                // relaxed fallbacks below — it's physically occupied.
                excluding: excluded.union(crossTrackExcluded),
                starterSiteIDs: PumpSite.starterSiteIDs(for: deviceType)
            )
        }

        var next = deal(excluding: offLimits.union(shownSiteIDs))
        if next.count < Self.suggestionCount {
            shownSiteIDs = []
            let rotated = deal(excluding: offLimits.union(current))
            if rotated.isEmpty {
                // Small track (CGM): the whole non-recent pool is already on
                // screen, so re-excluding it just re-deals the same cards.
                // Relax the recency guard and exclude only the current set —
                // surfacing recently rested sites, which is exactly what
                // shuffle promises. Excluding `current` guarantees the deal
                // differs from what's shown whenever any other site exists.
                let rested = deal(excluding: current)
                next = rested.isEmpty ? deal(excluding: []) : rested
            } else {
                next = rotated
            }
        }
        withAnimation(selectionAnimation) {
            suggestions = next
            selectedSite = nil
        }
        shownSiteIDs.formUnion(next.map(\.id))
        shuffleCount += 1
    }

    /// The one write in the flow: atomically closes the previous Pod and
    /// records the new placement. On failure the journal is untouched and
    /// the user stays here. `openCompanion` hands off to the companion app
    /// (the primary "Continue" button); the checkmark saves without leaving
    /// the app. Guarded so a fast double-tap can't record two placements.
    private func finishPlacement(_ site: PumpSite, openCompanion: Bool) {
        guard !isSaving else { return }
        isSaving = true
        do {
            try JournalStore(context: modelContext).startPlacement(siteID: site.id, deviceType: deviceType)
            savedCount += 1
            // Hand off to this track's own companion (pump and sensor differ).
            let companionRaw = UserDefaults.standard.string(forKey: CompanionApp.storageKey(for: deviceType))
                ?? CompanionApp.loop.rawValue
            if openCompanion, let url = CompanionApp(rawValue: companionRaw)?.launchURL {
                openURL(url)
            }
            dismiss()
        } catch {
            isSaving = false
            saveError = error
        }
    }
}

#Preview("New Pod flow") {
    NewPodFlowView()
        .modelContainer(for: PlacementRecord.self, inMemory: true)
}

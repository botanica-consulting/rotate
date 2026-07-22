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

    @State private var suggestions: [PumpSite] = []
    @State private var lastUsedBySite: [String: Date] = [:]
    @State private var recency = SiteRecencyModel(history: [])
    @State private var shownSiteIDs: Set<String> = []
    @State private var selectedSite: PumpSite?
    /// Site being placed on the instruction screen — not yet saved.
    @State private var pendingSite: PumpSite?
    @State private var savedCount = 0
    @State private var saveError: Error?

    @AppStorage(CompanionApp.storageKey) private var companionRaw = CompanionApp.loop.rawValue

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
                            shuffle()
                        } label: {
                            Image(systemName: "shuffle")
                        }
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
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("Save and return to the app")
                            .accessibilityIdentifier("savePlacementButton")
                        }
                    }
                }
        }
        .sensoryFeedback(.selection, trigger: selectedSite)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: shownSiteIDs)
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

    private var choosingContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, site in
                        SiteSuggestionCard(
                            site: site,
                            lastUsed: lastUsedBySite[site.id],
                            tier: recency.tier(for: site.id),
                            isSelected: selectedSite == site,
                            index: index
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
        let history = fetchHistory()
        lastUsedBySite = PlacementTimeline(records: history).lastUsedBySite
        recency = SiteRecencyModel(history: history)
        suggestions = SiteSuggestionEngine().suggestions(
            from: PumpSite.sites(for: deviceType),
            history: history,
            excluding: recency.veryRecentSiteIDs,
            starterSiteIDs: PumpSite.starterSiteIDs(for: deviceType)
        )
        shownSiteIDs = Set(suggestions.map(\.id))
    }

    /// Deals a fresh set: everything shown so far is excluded, which pulls in
    /// progressively more recently used ("yellow") sites. The last three used
    /// sites are never offered. When the pool runs dry, the rotation resets.
    private func shuffle() {
        let history = fetchHistory()
        let engine = SiteSuggestionEngine()
        let offLimits = recency.veryRecentSiteIDs

        var next = engine.suggestions(
            from: PumpSite.sites(for: deviceType),
            history: history,
            excluding: offLimits.union(shownSiteIDs),
            starterSiteIDs: PumpSite.starterSiteIDs(for: deviceType)
        )
        if next.count < 4 {
            // Pool exhausted — restart the rotation from the top.
            next = engine.suggestions(
                from: PumpSite.sites(for: deviceType),
                history: history,
                excluding: offLimits,
                starterSiteIDs: PumpSite.starterSiteIDs(for: deviceType)
            )
            shownSiteIDs = []
        }
        withAnimation(selectionAnimation) {
            suggestions = next
            selectedSite = nil
        }
        shownSiteIDs.formUnion(next.map(\.id))
    }

    /// The one write in the flow: atomically closes the previous Pod and
    /// records the new placement. On failure the journal is untouched and
    /// the user stays here. `openCompanion` hands off to the companion app
    /// (the primary "Continue" button); the X saves without leaving the app.
    private func finishPlacement(_ site: PumpSite, openCompanion: Bool) {
        do {
            try JournalStore(context: modelContext).startPlacement(siteID: site.id, deviceType: deviceType)
            savedCount += 1
            if openCompanion, let url = CompanionApp(rawValue: companionRaw)?.launchURL {
                openURL(url)
            }
            dismiss()
        } catch {
            saveError = error
        }
    }
}

#Preview("New Pod flow") {
    NewPodFlowView()
        .modelContainer(for: PlacementRecord.self, inMemory: true)
}

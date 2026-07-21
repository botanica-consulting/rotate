import SwiftUI
import SwiftData

/// The full-screen new-Pod flow. One view, state-driven: choosing (four
/// suggestion cards, then a confirmation control once a card is selected)
/// and the Loop handoff after saving. The handoff is a state of this view,
/// not a separate navigation destination.
struct NewPodFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var suggestions: [PumpSite] = []
    @State private var lastUsedBySite: [String: Date] = [:]
    @State private var recency = SiteRecencyModel(history: [])
    @State private var shownSiteIDs: Set<String> = []
    @State private var selectedSite: PumpSite?
    @State private var savedSite: PumpSite?
    @State private var savedRecord: PlacementRecord?
    /// The previously current record, whose stop time this save stamped —
    /// kept so "Choose another site" can restore it.
    @State private var closedRecord: PlacementRecord?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if let savedSite {
                    LoopHandoffView(
                        site: savedSite,
                        onContinue: { dismiss() },
                        onChooseAnother: chooseAnotherSite
                    )
                    .transition(handoffTransition)
                } else {
                    choosingContent
                        .transition(.opacity)
                }
            }
            .background(AppBackground())
            // The full title ellipsizes at accessibility text sizes; fall back
            // to a shorter one there instead of truncating.
            .navigationTitle(
                savedSite != nil ? ""
                    : dynamicTypeSize.isAccessibilitySize ? "Next site"
                    : "Choose your next site"
            )
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if savedSite == nil {
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
            }
        }
        .sensoryFeedback(.selection, trigger: selectedSite)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: shownSiteIDs)
        .sensoryFeedback(.success, trigger: savedSite) { _, newValue in
            newValue != nil
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
                    confirm(site)
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

    private var handoffTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }

    private func fetchHistory() -> [PlacementRecord] {
        let descriptor = FetchDescriptor<PlacementRecord>(
            sortBy: [SortDescriptor(\.placedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func loadSuggestionsIfNeeded() {
        guard suggestions.isEmpty else { return }
        let history = fetchHistory()
        lastUsedBySite = Dictionary(grouping: history, by: \.siteID)
            .compactMapValues { $0.map(\.placedAt).max() }
        recency = SiteRecencyModel(history: history)
        suggestions = SiteSuggestionEngine().suggestions(
            from: PumpSite.catalog,
            history: history,
            excluding: recency.veryRecentSiteIDs
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
            from: PumpSite.catalog,
            history: history,
            excluding: offLimits.union(shownSiteIDs)
        )
        if next.count < 4 {
            // Pool exhausted — restart the rotation from the top.
            next = engine.suggestions(
                from: PumpSite.catalog,
                history: history,
                excluding: offLimits
            )
            shownSiteIDs = []
        }
        withAnimation(selectionAnimation) {
            suggestions = next
            selectedSite = nil
        }
        shownSiteIDs.formUnion(next.map(\.id))
    }

    private func confirm(_ site: PumpSite) {
        let record = PlacementRecord(siteID: site.id)
        // The outgoing Pod comes off when the new one goes on.
        if let current = fetchHistory().first, current.removedAt == nil {
            current.removedAt = record.placedAt
            closedRecord = current
        }
        modelContext.insert(record)
        try? modelContext.save()
        savedRecord = record
        withAnimation(selectionAnimation) {
            savedSite = site
        }
    }

    private func chooseAnotherSite() {
        if let savedRecord {
            modelContext.delete(savedRecord)
        }
        closedRecord?.removedAt = nil
        try? modelContext.save()
        savedRecord = nil
        closedRecord = nil
        withAnimation(selectionAnimation) {
            savedSite = nil
            selectedSite = nil
        }
    }
}

#Preview("New Pod flow") {
    NewPodFlowView()
        .modelContainer(for: PlacementRecord.self, inMemory: true)
}

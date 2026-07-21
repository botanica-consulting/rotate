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

    @State private var suggestions: [PumpSite] = []
    @State private var lastUsedBySite: [String: Date] = [:]
    @State private var selectedSite: PumpSite?
    @State private var savedSite: PumpSite?
    @State private var savedRecord: PlacementRecord?
    @Namespace private var glassNamespace

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
            .navigationTitle(savedSite == nil ? "Choose your next site" : "")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if savedSite == nil {
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
        .sensoryFeedback(.success, trigger: savedSite) { _, newValue in
            newValue != nil
        }
        .task {
            loadSuggestionsIfNeeded()
        }
    }

    private var choosingContent: some View {
        GlassEffectContainer(spacing: 24) {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, site in
                            SiteSuggestionCard(
                                site: site,
                                lastUsed: lastUsedBySite[site.id],
                                isSelected: selectedSite == site,
                                index: index,
                                namespace: glassNamespace
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
    }

    private var selectionAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.35)
    }

    private var handoffTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }

    private func loadSuggestionsIfNeeded() {
        guard suggestions.isEmpty else { return }
        let descriptor = FetchDescriptor<PlacementRecord>(
            sortBy: [SortDescriptor(\.placedAt, order: .reverse)]
        )
        let history = (try? modelContext.fetch(descriptor)) ?? []
        lastUsedBySite = Dictionary(grouping: history, by: \.siteID)
            .compactMapValues { $0.map(\.placedAt).max() }
        suggestions = SiteSuggestionEngine().suggestions(
            from: PumpSite.catalog,
            history: history
        )
    }

    private func confirm(_ site: PumpSite) {
        let record = PlacementRecord(siteID: site.id)
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
            try? modelContext.save()
        }
        savedRecord = nil
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

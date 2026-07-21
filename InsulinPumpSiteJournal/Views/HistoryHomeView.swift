import SwiftUI
import SwiftData

/// Root view: the current placement, chronological history, and the New Pod
/// entry point. History content stays on plain, high-contrast surfaces —
/// Liquid Glass is reserved for the New Pod button.
struct HistoryHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlacementRecord.placedAt, order: .reverse)
    private var records: [PlacementRecord]

    @State private var showingNewPod = false
    @State private var showingBodyMap = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .background(AppBackground())
            .navigationTitle("Sites")
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
            .safeAreaInset(edge: .bottom) {
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
            .fullScreenCover(isPresented: $showingNewPod) {
                NewPodFlowView()
            }
            .sheet(isPresented: $showingBodyMap) {
                BodyMapView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .fontDesign(.rounded)
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

    private var historyList: some View {
        List {
            if let current = records.first {
                Section("Current") {
                    currentCard(for: current)
                }
            }

            Section("History") {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    historyRow(for: record, index: index)
                }
                .onDelete(perform: deleteRecords)
            }

            Section {
                EmptyView()
            } footer: {
                safetyFooter
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func currentCard(for record: PlacementRecord) -> some View {
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
                BodyThumbnail(site: site, fill: AppTheme.recent)
                    .frame(height: 96)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Current site: \(siteTitle(for: record)), on for \(PodAgeCounter.spokenText(at: .now, since: record.placedAt)), placed \(absoluteDate(for: record))"
        )
    }

    private func historyRow(for record: PlacementRecord, index: Int) -> some View {
        HStack {
            Text(siteTitle(for: record))
            Spacer()
            Text(record.placedAt.formatted(.relative(presentation: .named)))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(siteTitle(for: record)), placed \(absoluteDate(for: record))"
        )
        .accessibilityIdentifier("historyRow-\(index)")
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

    private func absoluteDate(for record: PlacementRecord) -> String {
        record.placedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func deleteRecords(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(records[offset])
        }
        try? modelContext.save()
    }
}

#Preview("Home") {
    HistoryHomeView()
        .modelContainer(for: PlacementRecord.self, inMemory: true)
}

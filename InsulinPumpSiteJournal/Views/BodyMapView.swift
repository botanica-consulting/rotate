import SwiftUI
import SwiftData

/// A recency "heatmap" of every catalog site on the front and rear
/// silhouettes, using the app-wide tier scale: red = last three used sites,
/// orange = recent, yellow = relatively recent, hollow = rested or never
/// used. The current site carries a ring — state is never encoded by color
/// alone (every marker also has a spoken description).
struct BodyMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PlacementRecord.placedAt, order: .reverse)
    private var records: [PlacementRecord]
    @AppStorage(BodyType.storageKey) private var bodyTypeRaw = BodyType.neutral.rawValue
    @State private var showingLegend = false

    private var bodyType: BodyType {
        BodyType(rawValue: bodyTypeRaw) ?? .neutral
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Body type", selection: $bodyTypeRaw) {
                        ForEach(BodyType.allCases) { type in
                            Text(type.displayName).tag(type.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("bodyTypePicker")

                    HStack(alignment: .top, spacing: 24) {
                        mapFigure(for: .front, title: "Front")
                        mapFigure(for: .rear, title: "Rear")
                    }

                    Text("When changing your Pod, Insulet recommends a site at least 1 inch from the previous one, 2 inches from the navel, and away from waistbands or areas where clothing rubs. Rotating sites gives each area time to recover.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Body map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingLegend = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("How to read this map")
                    .accessibilityIdentifier("legendButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close body map")
                    .accessibilityIdentifier("closeBodyMapButton")
                }
            }
            .sheet(isPresented: $showingLegend) {
                legendSheet
            }
        }
    }

    // MARK: Heat model

    private var lastUsedBySite: [String: Date] {
        Dictionary(grouping: records, by: \.siteID)
            .compactMapValues { $0.map(\.placedAt).max() }
    }

    private var currentSiteID: String? {
        records.first?.siteID
    }

    private var recency: SiteRecencyModel {
        SiteRecencyModel(history: records)
    }

    /// The same four sites the new-Pod flow would suggest right now.
    private var recommendedSiteIDs: Set<String> {
        Set(SiteSuggestionEngine().suggestions(
            from: PumpSite.catalog,
            history: records,
            excluding: SiteRecencyModel(history: records).veryRecentSiteIDs
        ).map(\.id))
    }

    // MARK: Figures

    private func mapFigure(for bodyView: PumpSite.BodyView, title: String) -> some View {
        VStack(spacing: 8) {
            Image(bodyType.assetName(for: bodyView))
                .resizable()
                .scaledToFit()
                .opacity(AppTheme.silhouetteOpacity)
                .overlay {
                    GeometryReader { geometry in
                        ForEach(PumpSite.catalog.filter { $0.bodyView == bodyView }) { site in
                            if let area = SiteAreaCatalog.area(for: site.id, bodyType: bodyType) {
                                areaOverlay(for: site, area: area, in: geometry)
                            } else {
                                marker(for: site)
                                    .position(
                                        x: geometry.size.width * site.markerPosition.x,
                                        y: geometry.size.height * site.markerPosition.y
                                    )
                            }
                        }
                    }
                }

            Text(title)
                .font(.caption.smallCaps())
                .foregroundStyle(.secondary)
        }
    }

    /// The anatomical mounting area: recency-colored fill under the shared
    /// hairline outline. The outline hue is the only thing that varies —
    /// primary for the current site, Loop fresh green for the recommended
    /// ones, the neutral grid gray otherwise — never its weight. VoiceOver
    /// focuses a 44pt element at the area's centroid rather than the whole
    /// figure.
    @ViewBuilder
    private func areaOverlay(for site: PumpSite, area: SiteArea, in geometry: GeometryProxy) -> some View {
        let tier = recency.tier(for: site.id)
        let isCurrent = site.id == currentSiteID
        let isRecommended = recommendedSiteIDs.contains(site.id)
        let outline: Color = isCurrent ? .primary
            : isRecommended ? AppTheme.fresh
            : AppTheme.areaOutline

        SiteAreaHighlight(
            area: area,
            fill: tier == .base ? nil : AppTheme.color(for: tier),
            outline: outline
        )
            .accessibilityHidden(true)
            .overlay {
                Color.clear
                    .frame(width: 44, height: 44)
                    .position(
                        x: geometry.size.width * site.markerPosition.x,
                        y: geometry.size.height * site.markerPosition.y
                    )
                    .accessibilityElement()
                    .accessibilityLabel(
                        accessibilityDescription(for: site, isCurrent: isCurrent, isRecommended: isRecommended)
                    )
            }
    }

    private func marker(for site: PumpSite) -> some View {
        let tier = recency.tier(for: site.id)
        let isCurrent = site.id == currentSiteID
        let isRecommended = recommendedSiteIDs.contains(site.id)

        return Circle()
            .fill(tier == .base ? Color.clear : AppTheme.color(for: tier))
            .overlay {
                Circle().stroke(
                    tier == .base ? AppTheme.areaOutline : Color(.systemBackground),
                    lineWidth: AppTheme.areaLineWidth
                )
            }
            .overlay {
                if isCurrent {
                    Circle()
                        .stroke(.primary, lineWidth: AppTheme.areaLineWidth)
                        .padding(-4)
                } else if isRecommended {
                    Circle()
                        .stroke(AppTheme.fresh, lineWidth: AppTheme.areaLineWidth)
                        .padding(-4)
                }
            }
            .frame(width: 20, height: 20)
            .accessibilityElement()
            .accessibilityLabel(
                accessibilityDescription(for: site, isCurrent: isCurrent, isRecommended: isRecommended)
            )
    }

    private func accessibilityDescription(
        for site: PumpSite,
        isCurrent: Bool,
        isRecommended: Bool
    ) -> String {
        var parts = [site.title]
        if isCurrent {
            parts.append("current site")
        }
        if isRecommended {
            parts.append("recommended next")
        }
        if let lastUsed = lastUsedBySite[site.id] {
            parts.append("last used \(lastUsed.formatted(date: .abbreviated, time: .omitted))")
        } else {
            parts.append("never used")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: Legend

    private var legendSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    legendRow(label: "Current site", fill: AppTheme.stale, outline: .primary)
                    legendRow(label: "Recommended next", fill: nil, outline: AppTheme.fresh)
                    legendRow(label: "Very recent (last 3 sites)", fill: AppTheme.stale)
                    legendRow(label: "Recent", fill: AppTheme.recent)
                    legendRow(label: "Relatively recent", fill: AppTheme.aging)
                    legendRow(label: "Rested or never used", fill: nil)

                    Text("Fill shows how recently each site was used; the outline marks the current site and the suggested next ones.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .accessibilityElement(children: .combine)
            }
            .navigationTitle("Reading the map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingLegend = false
                    }
                    .accessibilityIdentifier("closeLegendButton")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    /// Swatches use the exact area treatment: tier fill under the shared
    /// hairline outline.
    private func legendRow(
        label: String,
        fill: Color?,
        outline: Color = AppTheme.areaOutline
    ) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 5)
                .fill(fill.map { $0.opacity(AppTheme.areaFillOpacity) } ?? Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(outline, lineWidth: AppTheme.areaLineWidth)
                )
                .frame(width: 22, height: 16)
                .padding(2)
            Text(label)
                .font(.subheadline)
        }
    }
}

#Preview("Body map") {
    BodyMapView()
        .modelContainer(for: PlacementRecord.self, inMemory: true)
}

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

                    legend

                    Text("Warmer sites were used more recently. Prefer clear sites so warm ones can rest.")
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
                .overlay {
                    GeometryReader { geometry in
                        ForEach(PumpSite.catalog.filter { $0.bodyView == bodyView }) { site in
                            marker(for: site)
                                .position(
                                    x: geometry.size.width * site.markerPosition.x,
                                    y: geometry.size.height * site.markerPosition.y
                                )
                        }
                    }
                }

            Text(title)
                .font(.caption.smallCaps())
                .foregroundStyle(.secondary)
        }
    }

    private func marker(for site: PumpSite) -> some View {
        let tier = recency.tier(for: site.id)
        let isCurrent = site.id == currentSiteID
        let isRecommended = recommendedSiteIDs.contains(site.id)

        return Circle()
            .fill(tier == .base ? Color.clear : AppTheme.color(for: tier))
            .overlay {
                if tier == .base {
                    Circle().stroke(Color.secondary, lineWidth: 1.5)
                } else {
                    Circle().stroke(.background, lineWidth: 1.5)
                }
            }
            .overlay {
                if isCurrent {
                    Circle()
                        .stroke(.primary, lineWidth: 2)
                        .padding(-4)
                } else if isRecommended {
                    Circle()
                        .stroke(.green, lineWidth: 2)
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

    private var legend: some View {
        VStack(alignment: .leading, spacing: 10) {
            legendRow(label: "Current site") {
                Circle()
                    .fill(Color.red)
                    .overlay(Circle().stroke(.primary, lineWidth: 2).padding(-4))
            }
            legendRow(label: "Recommended next") {
                Circle().stroke(Color.green, lineWidth: 2)
            }
            legendRow(label: "Very recent (last 3 sites)") {
                Circle().fill(Color.red)
            }
            legendRow(label: "Recent") {
                Circle().fill(Color.orange)
            }
            legendRow(label: "Relatively recent") {
                Circle().fill(Color.yellow)
            }
            legendRow(label: "Rested or never used") {
                Circle().stroke(Color.secondary, lineWidth: 1.5)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: .rect(cornerRadius: AppTheme.cardCornerRadius))
        .accessibilityElement(children: .combine)
    }

    private func legendRow(label: String, @ViewBuilder swatch: () -> some View) -> some View {
        HStack(spacing: 12) {
            swatch()
                .frame(width: 14, height: 14)
                .padding(4)
            Text(label)
                .font(.subheadline)
        }
    }
}

#Preview("Body map") {
    BodyMapView()
        .modelContainer(for: PlacementRecord.self, inMemory: true)
}

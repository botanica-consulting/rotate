import SwiftUI
import SwiftData

/// A recency "heatmap" of every catalog site on the front and rear
/// silhouettes. Recency is magnitude, so it uses a single-hue sequential
/// ramp (orange, stronger = more recent); never-used sites are hollow
/// outlines and the current site carries a ring — state is never encoded by
/// color alone.
struct BodyMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PlacementRecord.placedAt, order: .reverse)
    private var records: [PlacementRecord]

    /// Sites older than this read as fully "rested".
    private static let restWindowDays: Double = 30

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    HStack(alignment: .top, spacing: 24) {
                        mapFigure(for: .front, title: "Front")
                        mapFigure(for: .rear, title: "Rear")
                    }
                    .padding(.top, 8)

                    legend

                    Text("Warmer sites were used more recently. Prefer cool or hollow sites so recent ones can rest.")
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

    /// 1.0 = used just now, 0.0 = at or beyond the rest window. nil = never used.
    private func heat(for site: PumpSite) -> Double? {
        guard let lastUsed = lastUsedBySite[site.id] else { return nil }
        let days = Date.now.timeIntervalSince(lastUsed) / 86_400
        return max(0, 1 - min(days / Self.restWindowDays, 1))
    }

    // MARK: Figures

    private func mapFigure(for bodyView: PumpSite.BodyView, title: String) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let silhouette = BodySilhouette(bodyView: bodyView)
                silhouette
                    .fill(Color.primary.opacity(0.12))
                    .overlay(silhouette.stroke(Color.primary.opacity(0.35), lineWidth: 1))
                    .overlay {
                        ForEach(PumpSite.catalog.filter { $0.bodyView == bodyView }) { site in
                            marker(for: site)
                                .position(
                                    x: geometry.size.width * site.markerPosition.x,
                                    y: geometry.size.height * site.markerPosition.y
                                )
                        }
                    }
            }
            .aspectRatio(0.45, contentMode: .fit)

            Text(title)
                .font(.caption.smallCaps())
                .foregroundStyle(.secondary)
        }
    }

    private func marker(for site: PumpSite) -> some View {
        let heat = heat(for: site)
        let isCurrent = site.id == currentSiteID

        return Circle()
            .fill(heat.map { AppTheme.recent.opacity(0.25 + 0.75 * $0) } ?? Color.clear)
            .overlay {
                if heat == nil {
                    Circle().stroke(Color.secondary, lineWidth: 1.5)
                } else {
                    Circle().stroke(.background, lineWidth: 1.5)
                }
            }
            .overlay {
                if isCurrent {
                    Circle()
                        .stroke(AppTheme.recent, lineWidth: 2)
                        .padding(-4)
                }
            }
            .frame(width: 20, height: 20)
            .accessibilityElement()
            .accessibilityLabel(accessibilityDescription(for: site, isCurrent: isCurrent))
    }

    private func accessibilityDescription(for site: PumpSite, isCurrent: Bool) -> String {
        var parts = [site.title]
        if isCurrent {
            parts.append("current site")
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
                    .fill(AppTheme.recent)
                    .overlay(Circle().stroke(AppTheme.recent, lineWidth: 2).padding(-4))
            }
            legendRow(label: "Used recently") {
                Circle().fill(AppTheme.recent.opacity(0.85))
            }
            legendRow(label: "Rested") {
                Circle().fill(AppTheme.recent.opacity(0.3))
            }
            legendRow(label: "Never used") {
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

import SwiftUI
import SwiftData

/// A recency "heatmap" of every catalog site on the front and rear views of
/// the silhouette chosen in Settings, using the app-wide tier scale: red =
/// last three used sites,
/// orange = recent, yellow = relatively recent, hollow = rested or never
/// used. The current site carries a ring — state is never encoded by color
/// alone (every marker also has a spoken description).
struct BodyMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PlacementRecord.placedAt, order: .reverse)
    private var records: [PlacementRecord]
    @AppStorage(BodyType.storageKey) private var bodyTypeRaw = BodyType.neutral.rawValue
    /// Which track's heatmap is shown. The pump and sensor maps have their own
    /// sites, current marker, and recency coloring.
    @State private var selectedDevice: DeviceType = .pump
    @State private var showingLegend = false

    private var bodyType: BodyType {
        BodyType(rawValue: bodyTypeRaw) ?? .neutral
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Track", selection: $selectedDevice) {
                        ForEach(DeviceType.allCases) { device in
                            Text(device.displayName).tag(device)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("deviceTypePicker")

                    HStack(alignment: .top, spacing: 24) {
                        mapFigure(for: .front, title: "Front")
                        mapFigure(for: .rear, title: "Rear")
                    }

                    Text("Rotating sites gives each area time to recover.")
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

    /// Only the selected track's records drive the map.
    private var deviceRecords: [PlacementRecord] {
        records.filter { $0.deviceType == selectedDevice.rawValue }
    }

    private var timeline: PlacementTimeline {
        PlacementTimeline(records: deviceRecords)
    }

    private var lastUsedBySite: [String: Date] {
        timeline.lastUsedBySite
    }

    /// The badge marks only a device that is actually on right now.
    private var currentSiteID: String? {
        timeline.current?.siteID
    }

    private var recency: SiteRecencyModel {
        SiteRecencyModel(history: deviceRecords)
    }

    // MARK: Figures

    private func mapFigure(for bodyView: PumpSite.BodyView, title: String) -> some View {
        VStack(spacing: 8) {
            Image(bodyType.assetName(for: bodyView))
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .opacity(AppTheme.silhouetteOpacity)
                .overlay {
                    GeometryReader { geometry in
                        ForEach(PumpSite.sites(for: selectedDevice).filter { $0.bodyView == bodyView }) { site in
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
    /// hairline outline — identical treatment at every location, with a
    /// miniature Pod sitting on the current site. VoiceOver focuses a 44pt
    /// element at the area's centroid rather than the whole figure.
    @ViewBuilder
    private func areaOverlay(for site: PumpSite, area: SiteArea, in geometry: GeometryProxy) -> some View {
        let tier = recency.tier(for: site.id)
        let isCurrent = site.id == currentSiteID

        SiteAreaHighlight(area: area, fill: AppTheme.color(for: tier))
            .accessibilityHidden(true)
            .overlay {
                ZStack {
                    if isCurrent {
                        CurrentSiteBadge(device: selectedDevice)
                        .scaleEffect(AppTheme.currentBadgeMapScale)
                    }
                    Color.clear
                        .frame(width: 44, height: 44)
                        .accessibilityElement()
                        .accessibilityLabel(
                            accessibilityDescription(for: site, isCurrent: isCurrent)
                        )
                }
                .position(
                    x: geometry.size.width * site.markerPosition.x,
                    y: geometry.size.height * site.markerPosition.y
                )
            }
    }

    private func marker(for site: PumpSite) -> some View {
        let tier = recency.tier(for: site.id)
        let isCurrent = site.id == currentSiteID

        return Circle()
            .fill(AppTheme.color(for: tier).opacity(AppTheme.areaFillOpacity))
            .overlay {
                Circle().stroke(AppTheme.areaOutline, lineWidth: AppTheme.areaLineWidth)
            }
            .overlay {
                if isCurrent {
                    CurrentSiteBadge(device: selectedDevice)
                        .scaleEffect(AppTheme.currentBadgeMapScale)
                }
            }
            .frame(width: 20, height: 20)
            .accessibilityElement()
            .accessibilityLabel(
                accessibilityDescription(for: site, isCurrent: isCurrent)
            )
    }

    private func accessibilityDescription(
        for site: PumpSite,
        isCurrent: Bool
    ) -> String {
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

    private var legendSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    legendRow(label: "Current site") { CurrentSiteBadge(device: selectedDevice)
                        .scaleEffect(AppTheme.currentBadgeMapScale) }
                    legendRow(label: "Very recent (last 3 sites)") { swatch(fill: AppTheme.stale) }
                    legendRow(label: "Recent") { swatch(fill: AppTheme.recent) }
                    legendRow(label: "Relatively recent") { swatch(fill: AppTheme.aging) }
                    legendRow(label: "Least recently used, or never") { swatch(fill: AppTheme.restedShade) }

                    // Honest about what the colors mean: usage order, not a
                    // judgment of skin condition or tissue readiness.
                    Text("Colors reflect usage order only — gray sites are simply the ones used least recently, not a guarantee the skin has recovered. The \(selectedDevice.noun) marks the site in use now.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
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

    private func legendRow(label: String, @ViewBuilder marker: () -> some View) -> some View {
        HStack(spacing: 12) {
            marker()
                .frame(width: 24, height: 18)
            Text(label)
                .font(.subheadline)
        }
    }

    /// Tier swatches use the exact area treatment: fill under the shared
    /// hairline outline.
    private func swatch(fill: Color) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(fill.opacity(AppTheme.areaFillOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(AppTheme.areaOutline, lineWidth: AppTheme.areaLineWidth)
            )
            .frame(width: 22, height: 16)
    }
}

#Preview("Body map") {
    BodyMapView()
        .modelContainer(for: PlacementRecord.self, inMemory: true)
}

import SwiftUI

/// First-launch setup: a short, gentle walkthrough of what Rotate is, a
/// mandatory plain-language disclaimer, then a chance to keep the pre-set
/// defaults or tune each track. Shown once; `onFinish` records completion so
/// it never returns. The disclaimer sits before configuration on every path —
/// including Skip — so no one enters the app without seeing it.
struct SetupWizardView: View {
    var onFinish: () -> Void

    @AppStorage(BodyType.storageKey) private var bodyTypeRaw = BodyType.neutral.rawValue
    @State private var page = 0
    @State private var path: [WizardStep] = []

    private let pages = WizardPage.all

    enum WizardStep: Hashable {
        case disclaimer
        case config
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()
                VStack(spacing: 0) {
                    TabView(selection: $page) {
                        ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                            WizardPageView(page: page, bodyType: bodyType)
                                .padding(.horizontal, 28)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                    primaryButton
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Skip still routes through the disclaimer — it's the one
                    // screen no one may bypass.
                    Button("Skip") { path = [.disclaimer] }
                        .accessibilityIdentifier("wizardSkipButton")
                }
            }
            .navigationDestination(for: WizardStep.self) { step in
                switch step {
                case .disclaimer:
                    WizardDisclaimerView { path.append(.config) }
                case .config:
                    WizardConfigView(onFinish: onFinish)
                }
            }
        }
    }

    private var bodyType: BodyType {
        BodyType(rawValue: bodyTypeRaw) ?? .neutral
    }

    private var isLastPage: Bool { page >= pages.count - 1 }

    private var primaryButton: some View {
        Button {
            if isLastPage {
                path = [.disclaimer]
            } else {
                withAnimation { page += 1 }
            }
        } label: {
            Text("Continue")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(AppTheme.accent)
        .controlSize(.large)
        .accessibilityIdentifier("wizardContinueButton")
    }
}

// MARK: - Walkthrough pages

private struct WizardPage: Identifiable {
    enum Hero {
        case sites
        case devices
        case heatmap
    }

    let id: String
    let hero: Hero
    let title: String
    let message: String

    static let all: [WizardPage] = [
        WizardPage(
            id: "sites",
            hero: .sites,
            title: "Rotate",
            message: "Your pump and sensor go in a handful of spots around the body. Rotate keeps a simple map of them."
        ),
        WizardPage(
            id: "devices",
            hero: .devices,
            title: "One helper, two devices",
            message: "Rotate helps you choose the next site for your continuous glucose monitor and your automatic insulin delivery pump — each on its own rotation."
        ),
        WizardPage(
            id: "heatmap",
            hero: .heatmap,
            title: "See what's rested",
            message: "A color-coded body map shows how recently each site was used, so the freshest spot is easy to find."
        ),
    ]
}

private struct WizardPageView: View {
    let page: WizardPage
    let bodyType: BodyType

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            hero
                .frame(maxHeight: 300)
            VStack(spacing: 14) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var hero: some View {
        switch page.hero {
        case .sites:
            SiteHighlightFigure(bodyType: bodyType)
        case .devices:
            DeviceHeroView()
        case .heatmap:
            BodyMapDemoView(bodyType: bodyType)
        }
    }
}

// MARK: Page 1 — silhouette with areas, intermittent highlight

/// The front silhouette with every front mounting area outlined; one area at a
/// time lights up, cycling slowly, so the figure reads as "these are the
/// spots" without any color-code meaning yet.
private struct SiteHighlightFigure: View {
    let bodyType: BodyType

    private let sites = PumpSite.catalog.filter { $0.bodyView == .front }
    @State private var highlight = 0

    var body: some View {
        BodySilhouette(bodyType: bodyType, bodyView: .front)
            .overlay {
                GeometryReader { _ in
                    ForEach(Array(sites.enumerated()), id: \.element.id) { index, site in
                        if let area = SiteAreaCatalog.area(for: site.id, bodyType: bodyType) {
                            SiteAreaHighlight(
                                area: area,
                                fill: index == highlight ? AppTheme.glucose : .clear
                            )
                            .opacity(index == highlight ? 1 : 0.9)
                        }
                    }
                }
            }
            .task {
                guard sites.count > 1 else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.4))
                    if Task.isCancelled { return }
                    withAnimation(.easeInOut(duration: 0.6)) {
                        highlight = (highlight + 1) % sites.count
                    }
                }
            }
    }
}

// MARK: Page 2 — the two devices, using the app's own markers

/// The pump and the sensor shown with the exact markers the body map uses,
/// each seated on its track color — so the color coding introduced here
/// matches what the user sees everywhere else.
private struct DeviceHeroView: View {
    var body: some View {
        HStack(spacing: 28) {
            deviceMarker(.pump, caption: "AID pump")
            deviceMarker(.cgm, caption: "CGM sensor")
        }
    }

    private func deviceMarker(_ device: DeviceType, caption: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.tint(for: device).opacity(AppTheme.areaFillOpacity))
                    .overlay(Circle().stroke(AppTheme.areaOutline, lineWidth: AppTheme.areaLineWidth))
                    .frame(width: 112, height: 112)
                CurrentSiteBadge(device: device)
                    .scaleEffect(1.7)
            }
            VStack(spacing: 4) {
                DeviceChip(device: device)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: Page 3 — animated body-map heatmap demo

/// A living body map: the front and rear figures start as a spread-out
/// heatmap, then the view zooms into one site at a time, that site's color
/// deepening as if just used, before pulling back out — a few cycles, then the
/// whole map resets and it plays again.
private struct BodyMapDemoView: View {
    let bodyType: BodyType

    /// Sites walked through on each pass — a spread across both views, each
    /// starting rested so the "just got used" color change is visible.
    private static let tourSiteIDs = [
        "abdomen-left",
        "back-upper-arm-right",
        "front-thigh-right",
        "lower-back-left",
        "upper-buttock-right",
    ]

    /// Recency depth per site, 0 (rested) … 3 (just used).
    @State private var usage: [String: Int] = BodyMapDemoView.initialUsage()
    @State private var focusedSiteID: String?

    var body: some View {
        ZStack {
            HStack(alignment: .top, spacing: 18) {
                figure(.front)
                figure(.rear)
            }
            .opacity(focusedSiteID == nil ? 1 : 0)

            if let id = focusedSiteID, let site = PumpSite.site(for: id) {
                VignettedBodyThumbnail(site: site, fill: color(for: id))
                    .transition(.opacity)
            }
        }
        .task { await runTour() }
    }

    private func figure(_ bodyView: PumpSite.BodyView) -> some View {
        BodySilhouette(bodyType: bodyType, bodyView: bodyView)
            .overlay {
                GeometryReader { _ in
                    ForEach(PumpSite.catalog.filter { $0.bodyView == bodyView }) { site in
                        if let area = SiteAreaCatalog.area(for: site.id, bodyType: bodyType) {
                            SiteAreaHighlight(area: area, fill: color(for: site.id))
                        }
                    }
                }
            }
    }

    private func color(for siteID: String) -> Color {
        let tiers: [SiteRecencyModel.Tier] = [.base, .relativelyRecent, .recent, .veryRecent]
        let index = min(max(usage[siteID] ?? 0, 0), tiers.count - 1)
        return AppTheme.color(for: tiers[index])
    }

    private func runTour() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1.1))
            for id in Self.tourSiteIDs {
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.45)) { focusedSiteID = id }
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation(.easeInOut(duration: 0.8)) {
                    usage[id] = min(3, (usage[id] ?? 0) + 2)
                }
                try? await Task.sleep(for: .seconds(0.85))
                withAnimation(.easeInOut(duration: 0.45)) { focusedSiteID = nil }
                try? await Task.sleep(for: .seconds(0.5))
            }
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeInOut(duration: 1.0)) { usage = Self.initialUsage() }
        }
    }

    /// A varied starting heatmap so the map reads as lived-in before the tour.
    private static func initialUsage() -> [String: Int] {
        var usage: [String: Int] = [:]
        for site in PumpSite.catalog { usage[site.id] = 0 }
        usage["abdomen-right"] = 3
        usage["back-upper-arm-left"] = 2
        usage["outer-thigh-left"] = 1
        usage["lower-back-right"] = 2
        usage["upper-buttock-left"] = 1
        return usage
    }
}

// MARK: - Disclaimer (mandatory, on every path)

/// Plain-language statement of what Rotate is and isn't. Reached before
/// configuration whether the walkthrough is finished or skipped, so it can't
/// be bypassed. Its only action is to acknowledge and continue.
struct WizardDisclaimerView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("A quick note before you start")
                        .font(.title.bold())
                        .padding(.top, 8)

                    point(
                        icon: "book.closed.fill",
                        title: "A journal, not a medical device",
                        text: "Rotate only helps you keep track of where you place your pump and sensor. It doesn't diagnose, treat, or make any dosing decisions — always follow your own clinical guidance."
                    )
                    point(
                        icon: "lock.fill",
                        title: "Your data stays yours",
                        text: "Rotate collects nothing about you. Your journal lives on this device and your own private iCloud — it is never sent to us or to any server."
                    )
                    point(
                        icon: "heart.fill",
                        title: "Free and open-source",
                        text: "Rotate is made for the Type 1 community, free of charge, with its source open for anyone to inspect."
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            Button(action: onContinue) {
                Text("I understand")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(AppTheme.accent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .accessibilityIdentifier("wizardDisclaimerButton")
        }
        .background(AppBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
    }

    private func point(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Configuration (pre-configured; keep or edit)

/// The final wizard step: everything already works on sensible defaults — this
/// makes that explicit and offers a way to fine-tune. The Pump / Sensor rows
/// push into the same per-track screens Settings uses, so nothing is new.
struct WizardConfigView: View {
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    deviceLink(for: .pump)
                    deviceLink(for: .cgm)
                } header: {
                    Text("Your tracks")
                } footer: {
                    Text("Rotate is already set up with sensible defaults — every body area on, and a companion app ready to open after each placement. Start now to keep them, or tap a track to adjust which areas it rotates through and which app it opens. Everything is editable later in Settings.")
                }
            }
            .scrollContentBackground(.hidden)

            Button { onFinish() } label: {
                Text("Start rotating")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(AppTheme.accent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .accessibilityIdentifier("wizardStartButton")
        }
        .background(AppBackground())
        .navigationTitle("You're all set")
        .navigationBarTitleDisplayMode(.large)
    }

    private func deviceLink(for device: DeviceType) -> some View {
        NavigationLink {
            DeviceSettingsView(device: device)
        } label: {
            Text(device.displayName)
        }
        .accessibilityIdentifier(device == .pump ? "wizardPumpLink" : "wizardSensorLink")
    }
}

#Preview("Setup wizard") {
    SetupWizardView(onFinish: {})
}

#Preview("Disclaimer") {
    NavigationStack {
        WizardDisclaimerView(onContinue: {})
    }
}

#Preview("Wizard config") {
    NavigationStack {
        WizardConfigView(onFinish: {})
    }
}

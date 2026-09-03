import AppIntents
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
        case logo
        case devices
        case heatmap
        case shortcuts
    }

    let id: String
    let hero: Hero
    let title: String
    let message: String

    static let all: [WizardPage] = [
        WizardPage(
            id: "intro",
            hero: .logo,
            title: "Rotate",
            message: "Rotate is an AID/CGM journaling app, meant to help you rotate between injection sites easily."
        ),
        WizardPage(
            id: "devices",
            hero: .devices,
            title: "One helper, two devices",
            message: "Rotate tracks your pump and sensor separately and clearly."
        ),
        WizardPage(
            id: "heatmap",
            hero: .heatmap,
            title: "See what's rested",
            message: "A color-coded body map shows how recently each site was used, so the freshest spot is easy to find."
        ),
        WizardPage(
            id: "shortcuts",
            hero: .shortcuts,
            title: "Ask, or just glance",
            message: "Ask Siri how long your site has been on, or start the next one hands-free. Add the lock-screen widget to see the hour count without unlocking — tap it to start a new site."
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
        case .logo:
            LogoHero()
        case .devices:
            DeviceHeroView()
        case .heatmap:
            BodyMapDemoView(bodyType: bodyType)
        case .shortcuts:
            ShortcutsHeroView()
        }
    }
}

// MARK: Page 1 — the app logo

/// The app icon itself, rounded like on the Home Screen — no silhouette here,
/// since the body figure carries the later pages.
private struct LogoHero: View {
    var body: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 33, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
            .accessibilityHidden(true)
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

// MARK: Page 3 — scripted rotation on a live body map

/// A hands-off replay of the app in use: the front and rear figures start
/// seeded with a pump and a sensor already on the body and some past-use heat,
/// then the pump slides to its next two sites and the sensor to its next one —
/// each vacated spot heating up and the older heat cooling, exactly as the real
/// heatmap moves. After the run it resets and plays again.
private struct BodyMapDemoView: View {
    let bodyType: BodyType

    /// Recency depth per site, 0 (rested) … 3 (just used). Higher = hotter.
    @State private var usage: [String: Int] = [:]
    /// Where each device currently sits; the badge floats when this changes.
    @State private var pumpSite = ""
    @State private var sensorSite = ""

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            figure(.front)
            figure(.rear)
        }
        .task { await runScenario() }
    }

    private func figure(_ bodyView: PumpSite.BodyView) -> some View {
        BodySilhouette(bodyType: bodyType, bodyView: bodyView)
            .overlay {
                GeometryReader { geometry in
                    ForEach(PumpSite.catalog.filter { $0.bodyView == bodyView }) { site in
                        if let area = SiteAreaCatalog.area(for: site.id, bodyType: bodyType) {
                            SiteAreaHighlight(area: area, fill: color(for: site.id))
                        }
                    }
                    badge(.pump, on: bodyView, in: geometry)
                    badge(.cgm, on: bodyView, in: geometry)
                }
            }
    }

    /// The current-site marker for a device, drawn only on the figure that
    /// hosts its current site. Positioned by the site's marker, so a change of
    /// site animates as a float across the figure.
    @ViewBuilder
    private func badge(_ device: DeviceType, on bodyView: PumpSite.BodyView, in geometry: GeometryProxy) -> some View {
        let siteID = device == .pump ? pumpSite : sensorSite
        if let site = PumpSite.site(for: siteID), site.bodyView == bodyView {
            CurrentSiteBadge(device: device)
                // The badge is a fixed-point size; on these compact demo
                // figures that reads oversized, so scale it to the same
                // fraction of the figure width it occupies on the full body
                // map (~11%) instead of using the map's fixed scale directly.
                .scaleEffect(geometry.size.width * 0.11 / 21)
                .position(
                    x: geometry.size.width * site.markerPosition.x,
                    y: geometry.size.height * site.markerPosition.y
                )
        }
    }

    private func color(for siteID: String) -> Color {
        let tiers: [SiteRecencyModel.Tier] = [.base, .relativelyRecent, .recent, .veryRecent]
        let index = min(max(usage[siteID] ?? 0, 0), tiers.count - 1)
        return AppTheme.color(for: tiers[index])
    }

    // MARK: Script

    /// The rotation played out, in order. The pump keeps to front sites and the
    /// sensor to rear ones, so every move is a smooth float within its figure.
    /// Interleaved and long enough to read as an ongoing rotation before it
    /// loops.
    private static let script: [(DeviceType, String)] = [
        (.pump, "abdomen-right"),
        (.cgm, "back-upper-arm-right"),
        (.pump, "front-thigh-left"),
        (.cgm, "upper-buttock-left"),
        (.pump, "front-thigh-right"),
        (.cgm, "lower-back-right"),
        (.pump, "abdomen-left"),
        (.cgm, "outer-thigh-left"),
        (.pump, "abdomen-right"),
        (.cgm, "back-upper-arm-left"),
        (.pump, "front-thigh-left"),
        (.cgm, "upper-buttock-right"),
        (.pump, "abdomen-left"),
        (.cgm, "lower-back-left"),
    ]

    private func runScenario() async {
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 1.0)) { seed() }
            if await pause(2.0) { return }

            for (device, site) in Self.script {
                if await step({ move(device, to: site) }, then: 1.8) { return }
            }

            if await pause(1.6) { return } // hold the finished map before looping
        }
    }

    /// Applies a scripted change with animation, then holds. Returns true if
    /// the task was cancelled while waiting.
    private func step(_ change: @escaping () -> Void, then seconds: Double) async -> Bool {
        withAnimation(.easeInOut(duration: 1.0)) { change() }
        return await pause(seconds)
    }

    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return Task.isCancelled
    }

    /// Moves a device to a new site the way a real placement would shift the
    /// heat: everything cools one step, the vacated site and the new site turn
    /// hottest, and both devices' current sites stay hot (they're in use).
    private func move(_ device: DeviceType, to newSite: String) {
        for key in usage.keys where (usage[key] ?? 0) > 0 { usage[key]! -= 1 }
        let from = device == .pump ? pumpSite : sensorSite
        usage[from] = 3
        if device == .pump { pumpSite = newSite } else { sensorSite = newSite }
        usage[newSite] = 3
        usage[pumpSite] = 3
        usage[sensorSite] = 3
    }

    /// The starting board: a pump and a sensor already placed, plus a little
    /// past-use heat so the map reads as lived-in before the run.
    private func seed() {
        var seeded: [String: Int] = [:]
        for site in PumpSite.catalog { seeded[site.id] = 0 }
        pumpSite = "abdomen-left"
        sensorSite = "back-upper-arm-left"
        seeded[pumpSite] = 3
        seeded[sensorSite] = 3
        seeded["abdomen-right"] = 2
        seeded["front-thigh-right"] = 1
        seeded["back-upper-arm-right"] = 1
        seeded["lower-back-left"] = 2
        seeded["upper-buttock-right"] = 1
        usage = seeded
    }
}

// MARK: - Disclaimer (mandatory, on every path)

/// Plain-language statement of what Rotate is and isn't. Reached before
/// configuration whether the walkthrough is finished or skipped, so it can't
/// be bypassed. Its only action is to acknowledge and continue.
// MARK: Page 4 — Siri phrases and the lock-screen widget

/// The two hands-free entry points, shown as what the user actually sees: the
/// phrase they say, and a mock of the accessory widget. The `ShortcutsLink`
/// underneath opens the Shortcuts app, so the phrases can be renamed straight
/// away rather than only discovered later.
private struct ShortcutsHeroView: View {
    var body: some View {
        VStack(spacing: 18) {
            lockScreenMock

            VStack(alignment: .leading, spacing: 10) {
                phrase("How long has my pump been on in Rotate?")
                phrase("Start a new sensor site in Rotate.")
            }

            ShortcutsLink()
                .shortcutsLinkStyle(.automaticOutline)
                .accessibilityIdentifier("wizardShortcutsLink")
        }
    }

    /// A stand-in for the accessory widget, not the widget itself — a real one
    /// can't be rendered inside the app.
    private var lockScreenMock: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.quaternary)
                VStack(spacing: -1) {
                    Text("27h")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text("PUMP")
                        .font(.system(size: 7).weight(.semibold))
                        .opacity(0.7)
                }
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 1) {
                Text("SENSOR")
                    .font(.caption2.weight(.semibold))
                    .opacity(0.7)
                Text("62h")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("Left upper arm")
                    .font(.caption2)
                    .opacity(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.quaternary))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lock screen widgets showing the pump on 27 hours and the sensor on 62 hours.")
    }

    private func phrase(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "quote.opening")
                .font(.caption)
                .foregroundStyle(AppTheme.accent)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

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
                        text: "Rotate tracks where you place your pump and sensor. It doesn't diagnose, treat, or make dosing decisions — follow your clinical guidance."
                    )
                    point(
                        icon: "lock.fill",
                        title: "Your data stays yours",
                        text: "No account, no analytics, no tracking. Your journal syncs to your private iCloud — Apple holds that copy, nobody else — or turn sync off in Settings and keep it on this device."
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

    /// Shared with the What's New sheet — see `FeaturePoint`.
    private func point(icon: String, title: String, text: String) -> some View {
        FeaturePoint(icon: icon, title: title, text: text)
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
                    Text("Rotate is already set up with sensible defaults — every body area on, and a companion app ready to open after each placement. Start now to keep them, or tap a track to adjust which areas it rotates through and which app it opens. Everything is editable later in Settings — including adding custom sites, for spots the figure doesn't cover.")
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

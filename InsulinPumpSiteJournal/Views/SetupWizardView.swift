import SwiftUI

/// First-launch setup: a short walkthrough of how Rotate works, then a chance
/// to tune each track's areas and companion app — or keep the sensible
/// defaults — before landing on the journal. Shown once; `onFinish` records
/// completion so it never returns.
struct SetupWizardView: View {
    var onFinish: () -> Void

    @AppStorage(BodyType.storageKey) private var bodyTypeRaw = BodyType.neutral.rawValue
    @State private var page = 0
    @State private var showingConfig = false

    private let pages = WizardPage.all

    var body: some View {
        NavigationStack {
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
            .navigationDestination(isPresented: $showingConfig) {
                WizardConfigView(onFinish: onFinish)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { onFinish() }
                        .accessibilityIdentifier("wizardSkipButton")
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
                showingConfig = true
            } else {
                withAnimation { page += 1 }
            }
        } label: {
            Text(isLastPage ? "Set up" : "Continue")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(AppTheme.accent)
        .controlSize(.large)
        .accessibilityIdentifier("wizardContinueButton")
    }
}

/// One walkthrough page: a hero illustration built from the app's own visual
/// language, a title, and a short explanation.
private struct WizardPage: Identifiable {
    enum Hero {
        case silhouette
        case tracks
        case recency
    }

    let id: String
    let hero: Hero
    let title: String
    let message: String

    static let all: [WizardPage] = [
        WizardPage(
            id: "rotate",
            hero: .silhouette,
            title: "Rotate every site",
            message: "Give each pump and sensor spot time to recover by moving where you place them. Rotate keeps track so you don't have to."
        ),
        WizardPage(
            id: "tracks",
            hero: .tracks,
            title: "Pump and sensor, tracked apart",
            message: "Rotate follows each device on its own schedule — place a pump without disturbing your sensor's rotation, and the reverse."
        ),
        WizardPage(
            id: "recency",
            hero: .recency,
            title: "Always a rested spot",
            message: "Each time, Rotate suggests the sites that have rested longest and shows what's fresh on a color-coded body map."
        ),
    ]
}

private struct WizardPageView: View {
    let page: WizardPage
    let bodyType: BodyType

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 0)
            hero
                .frame(height: 220)
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
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var hero: some View {
        switch page.hero {
        case .silhouette:
            BodySilhouette(bodyType: bodyType, bodyView: .front)
        case .tracks:
            HStack(spacing: 20) {
                trackBadge(.pump)
                trackBadge(.cgm)
            }
        case .recency:
            recencyLegend
        }
    }

    private func trackBadge(_ device: DeviceType) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.tint(for: device).opacity(0.15))
                    .frame(width: 108, height: 108)
                Image(systemName: device == .pump ? "cross.vial.fill" : "sensor.tag.radiowaves.forward.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.tint(for: device))
            }
            DeviceChip(device: device)
        }
    }

    private var recencyLegend: some View {
        let tiers: [(SiteRecencyModel.Tier, String)] = [
            (.base, "Rested"),
            (.relativelyRecent, "Aging"),
            (.recent, "Recent"),
            (.veryRecent, "Just used"),
        ]
        return HStack(alignment: .top, spacing: 18) {
            ForEach(Array(tiers.enumerated()), id: \.offset) { _, entry in
                VStack(spacing: 10) {
                    Circle()
                        .fill(AppTheme.color(for: entry.0))
                        .frame(width: 30, height: 30)
                    Text(entry.1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// The final wizard step: tune each track (or keep defaults), then start. The
/// Pump / Sensor rows push into the same per-track screens Settings uses, so
/// there's nothing new to learn and every choice is editable later.
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
                    Text("Choose which areas each track rotates through and the app to open after a placement. Everything starts on sensible defaults — keep them, or change anything now or later in Settings.")
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

#Preview("Wizard config") {
    NavigationStack {
        WizardConfigView(onFinish: {})
    }
}

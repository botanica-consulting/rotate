import AppIntents
import SwiftUI
import SwiftData

@main
struct InsulinPumpSiteJournalApp: App {
    init() {
        // Registered here, not in a view: an intent can run before any view
        // exists (Siri on a cold launch), and StartPlacementIntent resolves the
        // router through @Dependency.
        AppDependencyManager.shared.add(dependency: AppRouter.shared)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}

/// Owns the model container so a failed store can't crash-loop the app:
/// if the store won't open (corruption, failed migration), the user gets a
/// recovery screen with retry and reset instead of a crash.
struct AppRootView: View {
    /// First-launch flag — flipped when the setup wizard finishes, so the
    /// walkthrough shows once and never again.
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    /// Mirrors `SyncSettings`. Observed here because the CloudKit mirror is
    /// decided when the container is built, so turning sync on or off has to
    /// rebuild it.
    @AppStorage(SyncSettings.storageKey) private var syncEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    /// Newest version whose changes have been shown. Existing users never see
    /// the wizard again, so this sheet is the only way a change in wording — or
    /// a new privacy switch — reaches them.
    @AppStorage(ReleaseNotes.lastSeenVersionKey) private var lastSeenVersion = ""
    @State private var showingWhatsNew = false
    @State private var containerResult = AppRootView.makeContainer()

    var body: some View {
        container
            // Reuses the recovery path's rebuild: the store file is the same
            // either way, so only the mirror changes.
            .onChange(of: syncEnabled) { _, _ in
                containerResult = Self.makeContainer()
            }
            .overlay { privacyShield }
            // A widget tap. The router holds the request until the journal is on
            // screen, so a cold launch works too.
            .onOpenURL { url in
                AppRouter.shared.handle(url)
            }
    }

    @ViewBuilder
    private var container: some View {
        switch containerResult {
        case .success(let container):
            rootContent
                .modelContainer(container)
        case .failure(let error):
            StoreRecoveryView(
                error: error,
                retry: { containerResult = Self.makeContainer() },
                resetAndRetry: {
                    Self.deleteStoreFiles()
                    containerResult = Self.makeContainer()
                }
            )
        }
    }

    /// iOS snapshots the interface for the app switcher, and a journal of body
    /// sites, dates and notes is not something to leave sitting in that
    /// snapshot. Cover the UI whenever the scene isn't active; it can flash
    /// briefly as a system sheet takes focus, which is the accepted cost.
    @ViewBuilder
    private var privacyShield: some View {
        if scenePhase != .active {
            ZStack {
                AppBackground()
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .transition(.opacity)
        }
    }

    /// The journal, or the one-time setup wizard on first launch.
    @ViewBuilder
    private var rootContent: some View {
        if shouldShowOnboarding {
            SetupWizardView(onFinish: {
                // A new install just read the current wording in the wizard, so
                // it starts up to date and never gets the What's New sheet too.
                lastSeenVersion = Self.currentVersion
                hasCompletedSetup = true
            })
        } else {
            HistoryHomeView()
                .sheet(isPresented: $showingWhatsNew) {
                    WhatsNewView(notes: pendingReleaseNotes) {
                        lastSeenVersion = Self.currentVersion
                        showingWhatsNew = false
                    }
                }
                .task {
                    showingWhatsNew = !pendingReleaseNotes.isEmpty
                }
        }
    }

    /// Changes this user hasn't been shown yet. Empty on a test launch, so the
    /// sheet never lands on top of the UI tests; `--uitest-whatsnew` forces it
    /// for its own visual QA.
    private var pendingReleaseNotes: [ReleaseNotes] {
        guard !isTestLaunch || CommandLine.arguments.contains("--uitest-whatsnew") else {
            return []
        }
        return ReleaseNotes.unseen(lastSeen: lastSeenVersion, current: Self.currentVersion)
    }

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// Whether to present the setup wizard. Test launches go straight to the
    /// journal so the existing UI tests are unaffected; `--uitest-onboarding`
    /// forces the wizard for its own visual QA.
    private var shouldShowOnboarding: Bool {
        if CommandLine.arguments.contains("--uitest-onboarding") { return true }
        if isTestLaunch { return false }
        return !hasCompletedSetup
    }

    /// A UI-test or unit-test host launch: straight to the journal, with nothing
    /// presented over it.
    private var isTestLaunch: Bool {
        CommandLine.arguments.contains("--uitest-reset")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static func makeContainer() -> Result<ModelContainer, Error> {
        #if DEBUG
        // UI tests launch with a clean in-memory store; --uitest-seed adds a
        // spread of past placements so recency tiers are visible in visual QA.
        // The unit-test host also stays in memory: tests build their own
        // containers, and the host must not require CloudKit entitlements.
        if CommandLine.arguments.contains("--uitest-reset")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return Result {
                let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(
                    for: PlacementRecord.self, CustomSite.self,
                    configurations: configuration
                )
                if CommandLine.arguments.contains("--uitest-seed") {
                    let context = ModelContext(container)
                    for (index, site) in PumpSite.catalog.prefix(9).enumerated() {
                        let placedAt = Date.now.addingTimeInterval(-Double(index + 1) * 86_400)
                        // Newest record is the current Pod (still on); the rest
                        // stop a deterministic 19-23h in, before the next record's
                        // start (the seed places one Pod per day).
                        let wornHours = Double(19 + (index * 7) % 5)
                        context.insert(PlacementRecord(
                            siteID: site.id,
                            placedAt: placedAt,
                            removedAt: index == 0 ? nil : placedAt.addingTimeInterval(wornHours * 3_600),
                            notes: index == 2 ? "Leaked on day two — replaced early." : ""
                        ))
                    }
                    // A parallel sensor track: newest still on, older ones worn
                    // ~10 days each and spaced so they never overlap.
                    for (index, site) in PumpSite.cgmCatalog.prefix(3).enumerated() {
                        let placedAt = Date.now.addingTimeInterval(-Double(index) * 11 * 86_400 - 3 * 86_400)
                        context.insert(PlacementRecord(
                            siteID: site.id,
                            placedAt: placedAt,
                            removedAt: index == 0 ? nil : placedAt.addingTimeInterval(10 * 86_400),
                            deviceType: DeviceType.cgm.rawValue
                        ))
                    }
                    try context.save()
                }
                return container
            }
        }
        #endif
        // Local store mirrored to the user's private CloudKit database.
        // Sync is account-scoped and automatic: with no iCloud account the
        // store still opens and works locally, and mirroring resumes when
        // an account appears.
        return Result {
            try ModelContainer(
                for: PlacementRecord.self, CustomSite.self,
                configurations: storeConfiguration()
            )
        }
    }

    /// The live store's configuration — shared so container creation and
    /// `deleteStoreFiles()` always resolve the same store URL.
    ///
    /// CloudKit keeps Development and Production schemas separate, and only
    /// Development auto-creates record types from this model — Production
    /// never does. So after changing `PlacementRecord`: run a debug build and
    /// save a record (types are created lazily, on first export), then
    /// CloudKit Dashboard → Deploy Schema Changes, *before* shipping the build
    /// that needs the new fields. TestFlight and App Store builds use
    /// Production, where a missing field fails silently — no error, sync just
    /// stops working. See issue #3.
    ///
    /// Sync can be turned off (Settings → iCloud sync). Both branches are built
    /// without an explicit `url:`, so they resolve to the same default store
    /// file and flipping the switch keeps the journal exactly where it was —
    /// `storeURLIsTheSameWithOrWithoutSync` in SyncSettingsTests guards that.
    private static func storeConfiguration() -> ModelConfiguration {
        guard SyncSettings.isEnabled else {
            return ModelConfiguration(cloudKitDatabase: .none)
        }
        return ModelConfiguration(cloudKitDatabase: .private(SyncSettings.cloudKitContainerID))
    }

    /// Last-resort recovery: remove the store files (and SQLite sidecars) so
    /// the next attempt starts from an empty journal.
    private static func deleteStoreFiles() {
        let storeURL = storeConfiguration().url
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: storeURL.path + suffix)
            )
        }
    }
}

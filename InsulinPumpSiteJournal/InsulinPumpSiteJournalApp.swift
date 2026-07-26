import SwiftUI
import SwiftData

@main
struct InsulinPumpSiteJournalApp: App {
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
    @State private var containerResult = AppRootView.makeContainer()

    var body: some View {
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

    /// The journal, or the one-time setup wizard on first launch.
    @ViewBuilder
    private var rootContent: some View {
        if shouldShowOnboarding {
            SetupWizardView(onFinish: { hasCompletedSetup = true })
        } else {
            HistoryHomeView()
        }
    }

    /// Whether to present the setup wizard. Test launches go straight to the
    /// journal so the existing UI tests are unaffected; `--uitest-onboarding`
    /// forces the wizard for its own visual QA.
    private var shouldShowOnboarding: Bool {
        if CommandLine.arguments.contains("--uitest-onboarding") { return true }
        if CommandLine.arguments.contains("--uitest-reset")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }
        return !hasCompletedSetup
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
                    for: PlacementRecord.self,
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
            try ModelContainer(for: PlacementRecord.self, configurations: storeConfiguration())
        }
    }

    /// The live store's configuration — shared so container creation and
    /// `deleteStoreFiles()` always resolve the same store URL.
    private static func storeConfiguration() -> ModelConfiguration {
        ModelConfiguration(cloudKitDatabase: .private("iCloud.consulting.botanica.rotate"))
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

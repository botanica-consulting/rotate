import SwiftUI
import SwiftData

@main
struct InsulinPumpSiteJournalApp: App {
    private let modelContainer: ModelContainer = {
        // UI tests launch with a clean in-memory store.
        if CommandLine.arguments.contains("--uitest-reset") {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(
                for: PlacementRecord.self,
                configurations: configuration
            )
        }
        // Local store in the standard application container: eligible for
        // normal encrypted device backups, no iCloud entitlement required.
        //
        // To enable iCloud sync (model is already CloudKit-compatible):
        //   1. In project.yml, uncomment the `entitlements:` block on the app
        //      target and regenerate (`xcodegen generate`).
        //   2. Change `cloudKitDatabase` below from `.none` to
        //      `.private("iCloud.io.github.0xa10.InsulinPumpSiteJournal")`.
        //   3. Build with a team that has the iCloud capability; test on a
        //      device or simulator signed into iCloud.
        let configuration = ModelConfiguration(cloudKitDatabase: .none)
        return try! ModelContainer(
            for: PlacementRecord.self,
            configurations: configuration
        )
    }()

    var body: some Scene {
        WindowGroup {
            HistoryHomeView()
        }
        .modelContainer(modelContainer)
    }
}

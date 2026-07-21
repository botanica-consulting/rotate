import SwiftUI
import SwiftData

@main
struct InsulinPumpSiteJournalApp: App {
    private let modelContainer: ModelContainer = {
        // UI tests launch with a clean in-memory store; --uitest-seed adds a
        // spread of past placements so recency tiers are visible in visual QA.
        if CommandLine.arguments.contains("--uitest-reset") {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(
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
                try? context.save()
            }
            return container
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

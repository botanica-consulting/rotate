import Foundation
import Testing
import SwiftData
@testable import InsulinPumpSiteJournal

@MainActor
struct PersistenceTests {
    @Test func placementSurvivesContextRecreationAndCanBeDeleted() throws {
        let storeURL = URL.temporaryDirectory
            .appending(path: "persistence-test-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let configuration = ModelConfiguration(url: storeURL)

        // Insert and save.
        let recordID: UUID
        do {
            let container = try ModelContainer(
                for: PlacementRecord.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let record = PlacementRecord(siteID: "front-thigh-left")
            recordID = record.id
            context.insert(record)
            try context.save()
        }

        // Recreate the container/context and verify the placement remains.
        do {
            let container = try ModelContainer(
                for: PlacementRecord.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let fetched = try context.fetch(FetchDescriptor<PlacementRecord>())
            #expect(fetched.count == 1)
            #expect(fetched.first?.id == recordID)
            #expect(fetched.first?.siteID == "front-thigh-left")

            // Delete and save.
            for record in fetched {
                context.delete(record)
            }
            try context.save()
        }

        // Recreate once more and verify removal.
        do {
            let container = try ModelContainer(
                for: PlacementRecord.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let fetched = try context.fetch(FetchDescriptor<PlacementRecord>())
            #expect(fetched.isEmpty)
        }
    }
}

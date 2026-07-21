import Foundation
import Testing
@testable import InsulinPumpSiteJournal

struct CompanionAppTests {
    @Test func loopLaunchesViaItsURLScheme() {
        // The scheme must stay `loop` — it's what every standard Loop build
        // registers, and it's allowlisted in LSApplicationQueriesSchemes.
        #expect(CompanionApp.loop.launchURL?.scheme == "loop")
    }

    @Test func noneHasNoLaunchURL() {
        #expect(CompanionApp.none.launchURL == nil)
    }

    @Test func storedValuesRoundTrip() {
        for app in CompanionApp.allCases {
            #expect(CompanionApp(rawValue: app.rawValue) == app)
        }
    }
}

import XCTest

/// App Store marketing screenshots, driven by fastlane `snapshot`.
///
/// Run through the `Screenshots` scheme (see `fastlane/Snapfile`), not the
/// default test plan — it seeds a demo journal (`--uitest-seed`) so every
/// surface looks lived-in, and captures the frames with a clean 9:41 status
/// bar. Each marketing surface is captured from its own fresh launch so the
/// walk never depends on back-navigation.
final class AppStoreScreenshotsUITests: XCTestCase {
    @MainActor
    func testAppStoreScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["--uitest-reset", "--uitest-seed"]

        // 1 — the home hero: what's on right now, both tracks at a glance.
        app.launch()
        XCTAssertTrue(app.buttons["currentPodCard"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 1.0)
        snapshot("01_Overview")

        // 2 — the recency heatmap that guides rotation.
        app.buttons["bodyMapButton"].tap()
        XCTAssertTrue(app.buttons["closeBodyMapButton"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.0)
        snapshot("02_BodyMap")
        app.buttons["closeBodyMapButton"].tap()

        // 3 — the running journal.
        if app.buttons["historyHintButton"].waitForExistence(timeout: 5) {
            app.buttons["historyHintButton"].tap()
            Thread.sleep(forTimeInterval: 1.2)
            snapshot("04_History")
        }

        // 4 — starting a new placement: least-recently-used suggestions.
        app.launch()
        XCTAssertTrue(app.buttons["newPodButton"].waitForExistence(timeout: 20))
        app.buttons["newPodButton"].tap()
        XCTAssertTrue(app.buttons["suggestionCard-0"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.0)
        snapshot("03_ChooseSite")

        // 5 — configuring which areas each track rotates through.
        app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 20))
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.buttons["sensorSettingsLink"].waitForExistence(timeout: 10))
        app.buttons["sensorSettingsLink"].tap()
        if app.buttons["sensorRegionsLink"].waitForExistence(timeout: 10) {
            app.buttons["sensorRegionsLink"].tap()
            Thread.sleep(forTimeInterval: 1.5)
            snapshot("05_Areas")
        }
    }
}

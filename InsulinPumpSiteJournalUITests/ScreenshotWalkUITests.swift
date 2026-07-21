import XCTest

/// Temporary visual-QA walk: captures a screenshot of every major surface.
/// Not part of the product test plan — used to review Liquid Glass, the
/// silhouettes, and marker placement.
final class ScreenshotWalkUITests: XCTestCase {
    @MainActor
    func testScreenshotWalk() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        // Optional Dynamic Type override for visual QA runs, e.g.
        // TEST_RUNNER_WALK_CONTENT_SIZE=UICTContentSizeCategoryAccessibilityExtraExtraLarge
        if let contentSize = ProcessInfo.processInfo.environment["WALK_CONTENT_SIZE"] {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        if ProcessInfo.processInfo.environment["WALK_SEED"] == "1" {
            app.launchArguments.append("--uitest-seed")
        }
        if let bodyType = ProcessInfo.processInfo.environment["WALK_BODY_TYPE"] {
            app.launchArguments += ["-bodyType", bodyType]
        }
        app.launch()

        // Host-side `simctl io screenshot` polling captures the frames;
        // each stage just holds still long enough to be photographed.
        func snap(_ name: String) {
            Thread.sleep(forTimeInterval: 3.0)
        }

        XCTAssertTrue(app.buttons["newPodButton"].waitForExistence(timeout: 5))
        snap("01-empty-home")

        app.buttons["newPodButton"].tap()
        XCTAssertTrue(app.buttons["suggestionCard-0"].waitForExistence(timeout: 5))
        snap("02-suggestion-grid")

        app.buttons["shuffleButton"].tap()
        snap("02b-shuffled-grid")
        app.buttons["shuffleButton"].tap()
        snap("02c-shuffled-again")

        app.buttons["suggestionCard-0"].tap()
        XCTAssertTrue(app.buttons["confirmSiteButton"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6) // let the glass morph settle
        snap("03-card-selected")

        app.buttons["suggestionCard-3"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        snap("04-selection-moved")

        app.buttons["confirmSiteButton"].tap()
        XCTAssertTrue(app.staticTexts["Site saved"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        snap("05-loop-handoff")

        app.buttons["continueInLoopButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["historyRow-0"].waitForExistence(timeout: 5))
        snap("06-history-home")

        app.buttons["bodyMapButton"].tap()
        XCTAssertTrue(app.buttons["closeBodyMapButton"].waitForExistence(timeout: 5))
        snap("07-body-map")

        app.buttons["legendButton"].tap()
        XCTAssertTrue(app.buttons["closeLegendButton"].waitForExistence(timeout: 5))
        snap("08-legend-sheet")
        app.buttons["closeLegendButton"].tap()
    }
}

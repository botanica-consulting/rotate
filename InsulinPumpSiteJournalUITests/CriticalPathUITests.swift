import XCTest

final class CriticalPathUITests: XCTestCase {
    @MainActor
    func testNewPodCriticalPath() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        // Launch → tap New Pod.
        let newPodButton = app.buttons["newPodButton"]
        XCTAssertTrue(newPodButton.waitForExistence(timeout: 5))
        newPodButton.tap()

        // Select the first suggestion.
        let firstCard = app.buttons["suggestionCard-0"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        firstCard.tap()

        // Confirm.
        let confirmButton = app.buttons["confirmSiteButton"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        // See the Loop handoff.
        XCTAssertTrue(app.staticTexts["Site saved"].waitForExistence(timeout: 5))

        // Dismiss.
        app.buttons["continueInLoopButton"].tap()

        // See the new record in history. With a clean store, the first
        // suggestion is the first starter site: upper-left abdomen.
        let newRow = app.descendants(matching: .any)["historyRow-0"]
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Upper-left abdomen"].firstMatch.waitForExistence(timeout: 5)
        )
    }
}

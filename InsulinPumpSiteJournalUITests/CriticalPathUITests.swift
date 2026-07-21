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

        // See the placement instructions and Loop handoff.
        XCTAssertTrue(app.staticTexts["Place your Pod"].waitForExistence(timeout: 5))

        // Dismiss.
        app.buttons["continueInLoopButton"].tap()

        // The hero page shows the new placement as the current Pod. With a
        // clean store, the first suggestion is the first starter site.
        let heroCard = app.buttons["currentPodCard"]
        XCTAssertTrue(heroCard.waitForExistence(timeout: 5))
        XCTAssertTrue(
            heroCard.label.localizedCaseInsensitiveContains("left abdomen"),
            "hero card should name the saved site, got: \(heroCard.label)"
        )

        // Page up to history and open the record.
        app.buttons["historyHintButton"].tap()
        let newRow = app.descendants(matching: .any)["historyRow-0"]
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8) // let the page-up scroll settle
        newRow.tap()

        // Add a note to the record and close it.
        let notesField = app.descendants(matching: .any)["notesField"]
        XCTAssertTrue(notesField.waitForExistence(timeout: 5))
        app.swipeUp() // raise the sheet so the notes field is reachable
        notesField.tap()
        notesField.typeText("Leaked a little")
        app.buttons["closeRecordButton"].tap()

        // The note round-trips: reopen the record and find the text.
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let savedField = app.descendants(matching: .any)["notesField"]
        XCTAssertTrue(savedField.waitForExistence(timeout: 5))
        XCTAssertTrue(
            (savedField.value as? String)?.contains("Leaked") == true,
            "note should persist, got: \(String(describing: savedField.value))"
        )
        app.buttons["closeRecordButton"].tap()
    }
}

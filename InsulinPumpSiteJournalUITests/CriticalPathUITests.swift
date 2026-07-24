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

        // Continue to the placement instructions.
        let confirmButton = app.buttons["confirmSiteButton"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()
        XCTAssertTrue(app.staticTexts["Place your pump"].waitForExistence(timeout: 5))

        // Nothing is saved yet — confirming here performs the save.
        app.buttons["continueInLoopButton"].tap()

        // The hero page shows the new placement as the current Pod. With a
        // clean store, the first suggestion is the first starter site.
        let heroCard = app.buttons["currentPodCard"]
        XCTAssertTrue(heroCard.waitForExistence(timeout: 5))
        XCTAssertTrue(
            heroCard.label.localizedCaseInsensitiveContains("left abdomen"),
            "hero card should name the saved site, got: \(heroCard.label)"
        )

        // Page up to history and open the record (rows are lazy — they exist
        // once the page-up scroll brings them in).
        app.buttons["historyHintButton"].tap()
        let newRow = app.descendants(matching: .any)["historyRow-0"]
        XCTAssertTrue(waitUntilHittable(newRow), "history row never became tappable")
        newRow.tap()

        // Add a note to the record and close it.
        let notesField = app.descendants(matching: .any)["notesField"]
        XCTAssertTrue(notesField.waitForExistence(timeout: 5))
        app.swipeUp() // raise the sheet so the notes field is reachable
        XCTAssertTrue(waitUntilHittable(notesField), "notes field never became tappable")
        notesField.tap()
        notesField.typeText("Leaked a little")
        app.buttons["closeRecordButton"].tap()

        // The note round-trips: reopen the record and find the text. The
        // scroll may have settled back on the hero while the sheet was up,
        // dropping the lazy row — page back to history first if so.
        let hint = app.buttons["historyHintButton"]
        if !newRow.exists, hint.waitForExistence(timeout: 2), hint.isHittable {
            hint.tap()
        }
        XCTAssertTrue(waitUntilHittable(newRow))
        newRow.tap()
        let savedField = app.descendants(matching: .any)["notesField"]
        XCTAssertTrue(savedField.waitForExistence(timeout: 5))
        XCTAssertTrue(
            (savedField.value as? String)?.contains("Leaked") == true,
            "note should persist, got: \(String(describing: savedField.value))"
        )

        // Deleting asks for confirmation; removing the only record empties
        // the journal (deletion never resurrects other state).
        app.swipeUp()
        let deleteButton = app.buttons["deleteRecordButton"]
        XCTAssertTrue(waitUntilHittable(deleteButton))
        deleteButton.tap()
        // Confirmation dialogs mirror their buttons in the element tree.
        let confirmDelete = app.buttons["confirmDeleteRecordButton"].firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.tap()
        XCTAssertTrue(
            app.staticTexts["No placements yet"].waitForExistence(timeout: 5),
            "deleting the only record should leave an empty journal"
        )
    }

    @MainActor
    func testNewSensorCriticalPath() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        // The sensor track is a peer of the pump track: its own New button,
        // its own flow, its own current card.
        let newSensorButton = app.buttons["newSensorButton"]
        XCTAssertTrue(newSensorButton.waitForExistence(timeout: 5))
        newSensorButton.tap()

        // Choose the first sensor suggestion and continue to instructions.
        let firstCard = app.buttons["suggestionCard-0"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        firstCard.tap()
        let confirmButton = app.buttons["confirmSiteButton"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        // Sensor-specific instructions (no manufacturer named).
        XCTAssertTrue(app.staticTexts["Place your sensor"].waitForExistence(timeout: 5))

        // Confirm performs the save and the sensor becomes current — on its own
        // card, independent of the pump track.
        app.buttons["continueInLoopButton"].tap()
        let sensorCard = app.buttons["currentSensorCard"]
        XCTAssertTrue(sensorCard.waitForExistence(timeout: 5))
        XCTAssertTrue(
            sensorCard.label.localizedCaseInsensitiveContains("left upper arm"),
            "sensor card should name the saved site, got: \(sensorCard.label)"
        )

        // The pump card remains in its empty state — placing a sensor never
        // touched the pump track.
        XCTAssertTrue(app.buttons["noPodCard"].waitForExistence(timeout: 5))

        // The body map exposes the Pump/Sensor toggle.
        app.buttons["bodyMapButton"].tap()
        XCTAssertTrue(app.otherElements["deviceTypePicker"].waitForExistence(timeout: 5)
            || app.segmentedControls["deviceTypePicker"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

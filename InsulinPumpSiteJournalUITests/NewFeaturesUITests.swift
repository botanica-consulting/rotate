import XCTest

/// The 1.1.1 surfaces, end to end: the editable timing pickers, the custom-site
/// screen and the floating-area cards it feeds, and the iCloud sync switch.
/// These are new screens, so this checks they actually render and are reachable
/// rather than only that the types compile.
final class NewFeaturesUITests: XCTestCase {
    @MainActor
    func testRecordTimesAreEditable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-seed"]
        app.launch()

        // Open the current pump record from the hero card.
        let heroCard = app.buttons["currentPodCard"]
        XCTAssertTrue(heroCard.waitForExistence(timeout: 5))
        heroCard.tap()

        // "On" is always editable; the seeded current record is still on, so
        // there is no "Off" picker to find.
        let onPicker = app.descendants(matching: .any)["onDatePicker"]
        XCTAssertTrue(onPicker.waitForExistence(timeout: 5), "the On picker should be offered")
        XCTAssertFalse(
            app.descendants(matching: .any)["offDatePicker"].exists,
            "a placement still on has no removal time to edit"
        )
        app.buttons["closeRecordButton"].tap()

        // A finished record: the seed closes every placement but the newest, so
        // a history row has both a stamped stop and an editable Off picker.
        app.buttons["historyHintButton"].tap()
        let row = app.descendants(matching: .any)["historyRow-1"]
        XCTAssertTrue(waitUntilHittable(row), "history row never became tappable")
        row.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["offDatePicker"].waitForExistence(timeout: 5),
            "a finished placement should offer its removal time"
        )
        app.buttons["closeRecordButton"].tap()
    }

    @MainActor
    func testCustomSiteCanBeAddedAndIsOfferedForAPlacement() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        app.buttons["settingsButton"].tap()
        let customSitesLink = app.descendants(matching: .any)["customSitesLink"]
        XCTAssertTrue(customSitesLink.waitForExistence(timeout: 5))
        customSitesLink.tap()

        let nameField = app.textFields["customSiteNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Left calf")
        app.buttons["addCustomSiteButton"].tap()

        XCTAssertTrue(
            app.staticTexts["Left calf"].waitForExistence(timeout: 5),
            "the new site should be listed"
        )

        // Back out of Settings and confirm it reached the site catalog — the
        // UserDefaults mirror is what makes that work.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["closeSettingsButton"].tap()

        app.buttons["newPodButton"].tap()
        let showAll = app.buttons["showAllButton"]
        XCTAssertTrue(showAll.waitForExistence(timeout: 5))
        showAll.tap()

        // Custom sites sort after the twelve built-ins, so scroll to the end.
        let card = app.descendants(matching: .any)["suggestionCard-12"]
        for _ in 0..<8 where !card.exists {
            app.swipeUp()
        }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "the custom site should be offered")
        XCTAssertTrue(
            card.label.localizedCaseInsensitiveContains("left calf"),
            "the custom card should name the site, got: \(card.label)"
        )
    }

    @MainActor
    func testICloudSyncCanBeTurnedOff() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        app.buttons["settingsButton"].tap()
        let toggle = app.switches["iCloudSyncToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1", "sync should default to on")

        // A Toggle row in a Form only reacts on the switch itself, and the
        // element's centre is the whitespace beside the label.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()

        // Turning it off is a decision about data already in iCloud, so it goes
        // through a dialog rather than straight through.
        // The dialog exposes each button twice (container + control).
        let keepCopy = app.buttons["turnOffSyncButton"].firstMatch
        XCTAssertTrue(keepCopy.waitForExistence(timeout: 5), "expected the turn-off dialog")
        XCTAssertTrue(
            app.buttons["turnOffSyncAndPurgeButton"].firstMatch.exists,
            "the dialog should also offer removing the iCloud copy"
        )
        keepCopy.tap()

        // Flipping the switch rebuilds the model container, so Settings has to
        // survive that and show the new state.
        let offToggle = app.switches["iCloudSyncToggle"]
        XCTAssertTrue(offToggle.waitForExistence(timeout: 10))
        XCTAssertEqual(offToggle.value as? String, "0", "sync should now read as off")
        XCTAssertTrue(
            app.descendants(matching: .any)["purgeICloudButton"].firstMatch.waitForExistence(timeout: 5),
            "with sync off, removing the iCloud copy should still be offered"
        )
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

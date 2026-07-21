import XCTest

/// Automated checks for the PRD accessibility requirements that XCUITest can
/// observe: minimum hit-target sizes, VoiceOver labels carrying absolute
/// dates, selection exposed as a trait (not color-only), and body-thumbnail
/// descriptions.
final class AccessibilityUITests: XCTestCase {
    @MainActor
    func testAccessibilityContract() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        // New Pod button: present, labeled, ≥44pt.
        let newPod = app.buttons["newPodButton"]
        XCTAssertTrue(newPod.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(newPod.frame.height, 44)
        newPod.tap()

        // Suggestion cards: ≥44pt, VoiceOver description mentions the body view.
        let firstCard = app.buttons["suggestionCard-0"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(firstCard.frame.height, 44)
        XCTAssertGreaterThanOrEqual(firstCard.frame.width, 44)
        XCTAssertTrue(
            firstCard.label.localizedCaseInsensitiveContains("body view"),
            "card label should describe the body view, got: \(firstCard.label)"
        )

        // Selection is exposed as a trait, not just color. The glass morph
        // briefly duplicates the element mid-animation, so let it settle and
        // resolve via firstMatch.
        XCTAssertFalse(firstCard.isSelected)
        firstCard.tap()
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(firstCard.firstMatch.isSelected)

        // Confirm control: ≥44pt and names the site.
        let confirm = app.buttons["confirmSiteButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(confirm.frame.height, 44)
        XCTAssertTrue(confirm.label.localizedCaseInsensitiveContains("abdomen"))
        confirm.tap()

        // Handoff buttons ≥44pt.
        let continueButton = app.buttons["continueInLoopButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(continueButton.frame.height, 44)
        XCTAssertGreaterThanOrEqual(app.buttons["chooseAnotherSiteButton"].frame.height, 44)
        continueButton.tap()

        // History row: VoiceOver label carries an absolute date (month name),
        // not only the relative "now".
        let row = app.descendants(matching: .any)["historyRow-0"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        XCTAssertTrue(
            monthNames.contains { row.label.contains($0) },
            "history row label should contain an absolute date, got: \(row.label)"
        )

        // Body map markers expose per-site descriptions.
        app.buttons["bodyMapButton"].tap()
        XCTAssertTrue(app.buttons["closeBodyMapButton"].waitForExistence(timeout: 5))
        let currentMarker = app.otherElements.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "current site")
        ).firstMatch
        XCTAssertTrue(currentMarker.waitForExistence(timeout: 5))
        let neverMarker = app.otherElements.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "never used")
        ).firstMatch
        XCTAssertTrue(neverMarker.exists)
    }
}

import XCTest

/// Throwaway visual-QA capture of the first-launch setup wizard.
final class WizardShotUITests: XCTestCase {
    @MainActor
    func testWizardShot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-onboarding"]
        app.launch()

        func snap(_ name: String) {
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
        }

        XCTAssertTrue(app.buttons["wizardContinueButton"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        snap("wizard-1")

        app.buttons["wizardContinueButton"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        snap("wizard-2")

        app.buttons["wizardContinueButton"].tap()
        // Capture the scripted rotation at several beats so the movement shows.
        Thread.sleep(forTimeInterval: 0.8)
        snap("wizard-3a-seed")
        Thread.sleep(forTimeInterval: 1.7)
        snap("wizard-3b-pump-moved")
        Thread.sleep(forTimeInterval: 3.0)
        snap("wizard-3c-later")

        // Page 4: the Siri phrases and the lock-screen widget mock.
        app.buttons["wizardContinueButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["wizardShortcutsLink"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        snap("wizard-4-shortcuts")

        // Last page → pushes the mandatory disclaimer.
        app.buttons["wizardContinueButton"].tap()
        XCTAssertTrue(app.buttons["wizardDisclaimerButton"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        snap("wizard-disclaimer")

        // Disclaimer → config step.
        app.buttons["wizardDisclaimerButton"].tap()
        XCTAssertTrue(app.buttons["wizardStartButton"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        snap("wizard-config")
    }
}

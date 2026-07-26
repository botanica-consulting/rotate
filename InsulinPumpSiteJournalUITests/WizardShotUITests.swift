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
        Thread.sleep(forTimeInterval: 0.6)
        snap("wizard-3")

        // Last page → "Set up" pushes the config step.
        app.buttons["wizardContinueButton"].tap()
        XCTAssertTrue(app.buttons["wizardStartButton"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        snap("wizard-config")
    }
}

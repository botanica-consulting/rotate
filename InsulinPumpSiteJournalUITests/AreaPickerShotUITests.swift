import XCTest

/// Throwaway visual-QA capture of the new area picker (Settings → Sensor areas).
final class AreaPickerShotUITests: XCTestCase {
    @MainActor
    func testAreaPickerShot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        func snap(_ name: String) {
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
        }

        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        app.buttons["settingsButton"].tap()

        XCTAssertTrue(app.buttons["sensorRegionsLink"].waitForExistence(timeout: 5))
        app.buttons["sensorRegionsLink"].tap()

        XCTAssertTrue(app.buttons["areaOption-back-upper-arm-left"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        snap("area-picker-all-on")

        // Exclude a couple of visible areas to show the greyed-out state.
        app.buttons["areaOption-abdomen-left"].tap()
        app.buttons["areaOption-front-thigh-right"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        snap("area-picker-some-off")
    }
}

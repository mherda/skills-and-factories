import XCTest

/// Acceptance criteria that need a tap ("tap X, then Y happens") are proven
/// here: simctl can't tap, so a UI test is the only evidence that repeats
/// every review round.
final class FlowTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches with `-factoryNoPrompts`, so permission alerts don't block taps.
    @MainActor private func launch(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-factoryNoPrompts"] + arguments
        app.launch()
        return app
    }

    @MainActor func testSettingsOpensAndCloses() {
        let app = launch()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForNonExistence(timeout: 5))
    }
}

import XCTest

// UI tests implemented starting Story 1.2
final class TODOAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssert(app.state == .runningForeground)
    }

}

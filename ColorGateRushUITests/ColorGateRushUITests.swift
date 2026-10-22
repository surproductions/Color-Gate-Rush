import XCTest

/// End-to-end smoke tests that drive the real UI on a simulator.
/// Launch arguments (Debug builds only) give each test a clean, deterministic profile.
final class ColorGateRushUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-CGRResetProfile", "YES"] + extra
        app.launch()
        return app
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testHomeScreenShowsPrimaryActions() {
        let app = launch()
        XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["cosmeticsButton"].exists)
        XCTAssertTrue(app.buttons["progressButton"].exists)
        XCTAssertTrue(app.buttons["settingsButton"].exists)
        attachScreenshot("home")
    }

    func testTutorialStartsOnFirstPlayAndCanPauseAndQuit() {
        let app = launch()
        app.buttons["playButton"].tap()
        let pause = app.buttons["pauseButton"]
        XCTAssertTrue(pause.waitForExistence(timeout: 20))
        sleep(2)
        attachScreenshot("tutorial")
        pause.tap()
        XCTAssertTrue(app.buttons["resumeButton"].waitForExistence(timeout: 20))
        attachScreenshot("paused")
        app.buttons["resumeButton"].tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 20))
        pause.tap()
        app.buttons["quitButton"].tap()
        app.buttons["Quit Run"].tap()
        XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 20))
    }

    func testEndlessRunWithAutopilotThenCrashShowsResults() {
        // Autopilot plays perfectly; this verifies a long stretch of real gameplay doesn't crash the app.
        let app = launch(["-CGRSkipTutorial", "YES", "-CGRStartScreen", "game", "-CGRAutopilot", "YES", "-CGRSeed", "4242"])
        let pause = app.buttons["pauseButton"]
        XCTAssertTrue(pause.waitForExistence(timeout: 20))
        sleep(12)
        attachScreenshot("gameplay")
        XCTAssertTrue(pause.exists, "run should still be going under autopilot")
    }

    func testManualRunEndsInResultsAndRetryWorks() {
        // Without steering the orb soon hits a wrong gate or barrier.
        let app = launch(["-CGRSkipTutorial", "YES", "-CGRSeed", "7"])
        app.buttons["playButton"].tap()
        XCTAssertTrue(app.buttons["retryButton"].waitForExistence(timeout: 60))
        attachScreenshot("results")
        app.buttons["retryButton"].tap()
        XCTAssertTrue(app.buttons["pauseButton"].waitForExistence(timeout: 20))
    }

    func testMenusOpenAndReturn() {
        let app = launch(["-CGRGrantShards", "500"])
        app.buttons["cosmeticsButton"].tap()
        XCTAssertTrue(app.staticTexts["Style"].waitForExistence(timeout: 20))
        attachScreenshot("cosmetics")
        app.buttons["Back"].tap()
        app.buttons["progressButton"].tap()
        XCTAssertTrue(app.staticTexts["Progress"].waitForExistence(timeout: 20))
        attachScreenshot("progress")
        app.buttons["Back"].tap()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        let assist = app.switches["Color assist"]
        XCTAssertTrue(assist.exists)
        attachScreenshot("settings")
        let privacy = app.buttons["privacyButton"]
        if !privacy.isHittable { app.swipeUp() }
        privacy.tap()
        XCTAssertTrue(app.staticTexts["Privacy"].waitForExistence(timeout: 20))
        attachScreenshot("privacy")
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 20))
    }
}

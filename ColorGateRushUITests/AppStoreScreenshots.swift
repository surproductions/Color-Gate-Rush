import XCTest

/// Captures App Store screenshots. Run on a 6.9" simulator (iPhone 16/17 Pro Max) via the
/// "App Store Screenshots" workflow; the regular CI run skips this class.
/// Debug-only launch arguments put the app into realistic states (see DebugOptions).
final class AppStoreScreenshots: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
    }

    /// Menus animate continuously, which slows XCUITest's idle detection badly on CI;
    /// screens captured from the menus use Reduce Motion (gameplay keeps full effects).
    private let calm = ["-CGRReduceMotion", "YES"]

    private func launch(demo: Bool = true, _ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-CGRResetProfile", "YES"] + (demo ? ["-CGRDemoProfile", "YES"] : []) + extra
        app.launch()
        return app
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test01Home() {
        let app = launch(calm)
        XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 20))
        sleep(3)
        shot("store-home")
    }

    func test02Gameplay() {
        let app = launch(["-CGRStartScreen", "game", "-CGRAutopilot", "YES", "-CGRSeed", "2024"])
        XCTAssertTrue(app.buttons["pauseButton"].waitForExistence(timeout: 20))
        for second in stride(from: 8, through: 72, by: 4) {
            sleep(4)
            shot(String(format: "store-gameplay-midnight-%03d", second))
        }
    }

    func test03GameplaySynthwave() {
        let app = launch(["-CGRStartScreen", "game", "-CGRAutopilot", "YES", "-CGRSeed", "77",
                          "-CGRDemoTheme", "theme.synthwave"])
        XCTAssertTrue(app.buttons["pauseButton"].waitForExistence(timeout: 20))
        sleep(84)
        for second in stride(from: 88, through: 124, by: 3) {
            sleep(3)
            shot(String(format: "store-gameplay-synthwave-%03d", second))
        }
    }

    func test04Tutorial() {
        let app = launch(demo: false, calm)
        app.buttons["playButton"].tap()
        XCTAssertTrue(app.buttons["pauseButton"].waitForExistence(timeout: 20))
        sleep(4)
        shot("store-tutorial-a")
        sleep(2)
        shot("store-tutorial-b")
    }

    func test05Results() {
        let app = launch(["-CGRDemoBest", "300", "-CGRStartScreen", "game", "-CGRAutopilot", "YES",
                          "-CGRAutopilotSeconds", "55", "-CGRSeed", "31", "-CGRDemoTheme", "theme.ocean"])
        XCTAssertTrue(app.buttons["retryButton"].waitForExistence(timeout: 150))
        sleep(2)
        shot("store-results")
    }

    func test06Style() {
        let app = launch(calm)
        app.buttons["cosmeticsButton"].tap()
        XCTAssertTrue(app.staticTexts["Style"].waitForExistence(timeout: 20))
        sleep(1)
        shot("store-style-orbs")
        app.buttons["Themes"].tap()
        sleep(1)
        shot("store-style-themes")
    }

    func test07Progress() {
        let app = launch(calm)
        app.buttons["progressButton"].tap()
        XCTAssertTrue(app.staticTexts["Progress"].waitForExistence(timeout: 20))
        sleep(1)
        shot("store-progress")
    }

    func test08UnlockDialog() {
        let app = launch(calm)
        app.buttons["cosmeticsButton"].tap()
        let hex = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Hex Core'")).firstMatch
        XCTAssertTrue(hex.waitForExistence(timeout: 20))
        hex.tap()
        XCTAssertTrue(app.buttons["confirmUnlockButton"].waitForExistence(timeout: 20))
        sleep(1)
        shot("review-unlock-dialog")
        app.buttons["dialogCancelButton"].tap()
        let comet = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Void Gem'")).firstMatch
        if !comet.isHittable { app.swipeUp() }
        comet.tap()
        if app.buttons["playToEarnButton"].waitForExistence(timeout: 20) {
            sleep(1)
            shot("review-shortfall-dialog")
        }
    }

    func test09PauseMenu() {
        let app = launch(["-CGRStartScreen", "game", "-CGRAutopilot", "YES", "-CGRSeed", "5"])
        let pause = app.buttons["pauseButton"]
        XCTAssertTrue(pause.waitForExistence(timeout: 20))
        sleep(6)
        pause.tap()
        XCTAssertTrue(app.buttons["resumeButton"].waitForExistence(timeout: 20))
        sleep(1)
        shot("review-pause-menu")
        app.buttons["quitButton"].tap()
        if app.buttons["confirmQuitButton"].waitForExistence(timeout: 20) {
            sleep(1)
            shot("review-quit-dialog")
        }
    }
}

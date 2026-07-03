import XCTest

/// App Store screenshot harness. Runs the real app on a 6.9" simulator, drives
/// the primary flows with demo data, and attaches full-screen captures (extract
/// them from the .xcresult with `xcresulttool export attachments`).
///
///   xcodebuild test -project Kairo.xcodeproj -scheme KairoScreenshots \
///     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
///     -resultBundlePath build/screens.xcresult CODE_SIGNING_ALLOWED=NO
///
/// Run on an ERASED simulator (fresh install → seed banner shows) with the
/// status bar overridden to 9:41 via `simctl status_bar`. On a Simulator there
/// are no Apple Foundation Models, so Ask/Digest exercise the cloud answer
/// path — the captures show real generated, cited answers.
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testCaptureAppStoreScreenshots() throws {
        // ── 1. Home: seed demo data, check in, wait for the proactive card ──
        let seed = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "Load demo memories")).firstMatch
        XCTAssertTrue(seed.waitForExistence(timeout: 30), "seed banner should show on fresh install")
        seed.tap()
        XCTAssertTrue(seed.waitForNonExistence(timeout: 30), "seeding should hide the banner")

        let checkIn = app.buttons["Check in today"]
        if checkIn.waitForExistence(timeout: 10) {
            checkIn.tap()
            allowNotificationsIfAsked()   // in-context prompt fires after first check-in
            _ = app.staticTexts["Checked in today ✓"].waitForExistence(timeout: 15)
        }
        // Day-3 recall card (its prompt is generated — give it a moment).
        _ = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "↩"))
            .firstMatch.waitForExistence(timeout: 25)
        settle()
        shot("01-home")

        // ── 2. Ask: tap a suggestion, wait for the generated, cited answer ──
        app.tabBars.buttons["Ask"].tap()
        let suggestion = app.buttons["What triggers my bloating?"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 10))
        suggestion.tap()
        let answered = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "Remember this")).firstMatch
        XCTAssertTrue(answered.waitForExistence(timeout: 90), "Ask answer should arrive")
        settle()
        shot("02-ask")

        // ── 3. Review: reveal a flashcard ──
        app.tabBars.buttons["Review"].tap()
        let showAnswer = app.buttons["Show answer"]
        XCTAssertTrue(showAnswer.waitForExistence(timeout: 30), "demo cards should be due")
        showAnswer.tap()
        _ = app.buttons["Easy"].waitForExistence(timeout: 10)
        settle()
        shot("03-review")

        // ── 4. Digest: wait for the weekly reflection to generate ──
        app.tabBars.buttons["Digest"].tap()
        let digestHeader = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "memories")).firstMatch
        XCTAssertTrue(digestHeader.waitForExistence(timeout: 120), "digest should generate")
        settle()
        shot("04-digest")

        // ── 5. Settings: theme picker + widget previews ──
        app.tabBars.buttons["Home"].tap()
        let gear = app.buttons["Settings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 10))
        settle(1.5)   // let the widget previews render
        shot("05-settings")

        // ── 6. Sunset theme: switch and capture Home in the signature look ──
        let sunsetRow = app.buttons["Sunset"].exists
            ? app.buttons["Sunset"] : app.staticTexts["Sunset"]
        XCTAssertTrue(sunsetRow.waitForExistence(timeout: 5))
        sunsetRow.tap()
        // The theme switch rebuilds the root view, which dismisses the sheet;
        // tap Done only if it survived.
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 3) { done.tap() }
        XCTAssertTrue(app.staticTexts["RECENT MEMORIES"].waitForExistence(timeout: 15))
        settle()
        shot("06-home-sunset")
    }

    // MARK: - Helpers

    /// The notification permission prompt fires in context after the first
    /// check-in — approve it so the alert never blocks a later tap.
    private func allowNotificationsIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 8) { allow.tap() }
    }

    private func settle(_ seconds: TimeInterval = 0.8) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

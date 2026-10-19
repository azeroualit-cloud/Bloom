import XCTest

final class DailyUseUITests: XCTestCase {
    @MainActor
    func testCaptureCollectionAndOpenPreserveInput() {
        let (app, _) = captureNote(withCollection: true)
        let collection = app.descendants(matching: .any)["detail-collection"].firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertEqual(collection.value as? String, "Projects", diagnostics(app))
    }

    @MainActor
    func testBulkArchiveAndRestore() {
        let (app, _) = captureNote(withCollection: false)
        returnToLibrary(app)
        app.buttons["library-select"].tap()
        app.buttons["bulk-select-all"].tap()
        app.buttons["bulk-archive-action"].tap()
        XCTAssertEqual(app.staticTexts["library-count"].label, "0 contenuti")
        app.segmentedControls.buttons["Archivio"].tap()
        XCTAssertEqual(app.staticTexts["library-count"].label, "1 contenuti")
        app.buttons["bulk-select-all"].tap()
        app.buttons["bulk-archive-action"].tap()
        XCTAssertEqual(app.staticTexts["library-count"].label, "0 contenuti")
        app.segmentedControls.buttons["Libreria"].tap()
        XCTAssertEqual(app.staticTexts["library-count"].label, "1 contenuti")
    }

    @MainActor
    func testRediscoveryExhaustionAndRestart() {
        let (app, title) = captureNote(withCollection: false)
        returnToLibrary(app)
        app.tabBars.buttons["Riscopri"].tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), diagnostics(app))
        app.buttons["rediscovery-next"].tap()
        XCTAssertTrue(app.buttons["rediscovery-restart"].waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertFalse(app.staticTexts[title].exists)
        app.buttons["rediscovery-restart"].tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), diagnostics(app))
    }

    @MainActor
    private func captureNote(withCollection: Bool) -> (XCUIApplication, String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory"]
        app.launch()
        XCTAssertTrue(app.buttons["capture-add"].waitForExistence(timeout: 15))
        app.buttons["capture-add"].tap()
        app.buttons["capture-text"].tap()
        let title = app.textFields["capture-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Bloom test note")
        let body = app.textViews["capture-body"]
        body.tap()
        body.typeText("Saved note content")
        app.buttons["capture-keyboard-done"].tap()
        let enteredBody = body.value as? String ?? ""
        let enteredTitle = title.value as? String ?? ""
        XCTAssertFalse(enteredBody.isEmpty)
        XCTAssertFalse(enteredTitle.isEmpty)
        if withCollection {
            app.swipeUp()
            app.buttons["Crea raccolta"].tap()
            let collection = app.textFields["collection-name"]
            XCTAssertTrue(collection.waitForExistence(timeout: 10), diagnostics(app))
            collection.tap()
            collection.typeText("Projects")
            app.buttons["collection-save"].tap()
        }
        XCTAssertTrue(app.buttons["capture-save"].waitForExistence(timeout: 5))
        app.buttons["capture-save"].tap()
        XCTAssertTrue(app.staticTexts["Testo salvato. Puoi aggiungerne un altro."].waitForExistence(timeout: 5), diagnostics(app))
        app.buttons["Annulla"].tap()
        XCTAssertTrue(app.buttons["library-open-saved"].waitForExistence(timeout: 5), diagnostics(app))
        app.buttons["library-open-saved"].tap()
        let detail = app.staticTexts["detail-content-text"]
        XCTAssertTrue(detail.waitForExistence(timeout: 10), diagnostics(app))
        XCTAssertEqual(detail.label, enteredBody)
        return (app, enteredTitle)
    }

    @MainActor
    private func returnToLibrary(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["library-select"].waitForExistence(timeout: 5), diagnostics(app))
    }

    @MainActor
    private func diagnostics(_ app: XCUIApplication) -> String {
        "Navigation: \(app.navigationBars.allElementsBoundByIndex.map(\.identifier)); texts: \(app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: ", ")); buttons: \(app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: ", "))"
    }
}

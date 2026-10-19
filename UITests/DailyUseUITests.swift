import XCTest

final class DailyUseUITests: XCTestCase {
    @MainActor
    func testCaptureCollectionOpenBulkArchiveRestoreAndRediscover() {
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
        // Native keyboard correction is part of the input, not a persistence failure.
        let enteredBody = body.value as? String ?? ""
        let enteredTitle = title.value as? String ?? ""
        XCTAssertFalse(enteredBody.isEmpty)
        XCTAssertFalse(enteredTitle.isEmpty)
        app.swipeUp()
        app.buttons["Crea raccolta"].tap()
        let collection = app.textFields["collection-name"]
        XCTAssertTrue(collection.waitForExistence(timeout: 10),
            "Navigation: \(app.navigationBars.allElementsBoundByIndex.map(\.identifier)); fields: \(app.textFields.allElementsBoundByIndex.map(\.identifier)); buttons: \(app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: ", "))")
        collection.tap()
        collection.typeText("Projects")
        app.buttons["collection-save"].tap()
        XCTAssertTrue(app.buttons["capture-save"].waitForExistence(timeout: 5))
        app.buttons["capture-save"].tap()
        let detail = app.staticTexts["detail-content-text"]
        XCTAssertTrue(detail.waitForExistence(timeout: 10),
            "Navigation: \(app.navigationBars.allElementsBoundByIndex.map(\.identifier)); texts: \(app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: ", ")); buttons: \(app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: ", "))")
        XCTAssertEqual(detail.label, enteredBody)
        XCTAssertTrue(app.staticTexts["Projects"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["library-select"].waitForExistence(timeout: 5))
        app.buttons["library-select"].tap()
        app.buttons["Seleziona visibili"].tap()
        app.buttons["Archivia"].tap()
        app.segmentedControls.buttons["Archivio"].tap()
        app.buttons["Seleziona visibili"].tap()
        app.buttons["Ripristina"].tap()
        app.segmentedControls.buttons["Libreria"].tap()
        XCTAssertTrue(app.staticTexts[enteredTitle].exists)
        app.buttons["library-select"].tap()
        app.tabBars.buttons["Riscopri"].tap()
        XCTAssertTrue(app.staticTexts[enteredTitle].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Nuovo giro"].tap()
        XCTAssertTrue(app.staticTexts["Tutti i contenuti proposti"].waitForExistence(timeout: 5))
        app.buttons["Ricomincia"].tap()
        XCTAssertTrue(app.staticTexts[enteredTitle].waitForExistence(timeout: 5))
    }
}

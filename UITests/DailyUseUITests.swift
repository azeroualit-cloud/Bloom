import XCTest

final class DailyUseUITests: XCTestCase {
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
        title.typeText("Nota di prova")
        let body = app.textViews["capture-body"]
        body.tap()
        body.typeText("Contenuto personale per la prova")
        // Dismiss the keyboard without relying on its localized Done button.
        app.navigationBars["Aggiungi testo"].tap()
        app.swipeUp()
        app.buttons["Crea raccolta"].tap()
        let collection = app.textFields["Nome raccolta"]
        XCTAssertTrue(collection.waitForExistence(timeout: 5))
        collection.tap()
        collection.typeText("Progetti")
        app.buttons["collection-save"].tap()
        XCTAssertTrue(app.buttons["capture-save"].waitForExistence(timeout: 5))
        app.buttons["capture-save"].tap()
        XCTAssertTrue(app.staticTexts["Contenuto personale per la prova"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Progetti"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["library-select"].waitForExistence(timeout: 5))
        app.buttons["library-select"].tap()
        app.buttons["Seleziona visibili"].tap()
        app.buttons["Archivia"].tap()
        app.segmentedControls.buttons["Archivio"].tap()
        app.buttons["Seleziona visibili"].tap()
        app.buttons["Ripristina"].tap()
        app.segmentedControls.buttons["Libreria"].tap()
        XCTAssertTrue(app.staticTexts["Nota di prova"].exists)
        app.buttons["library-select"].tap()
        app.tabBars.buttons["Riscopri"].tap()
        XCTAssertTrue(app.staticTexts["Nota di prova"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Nuovo giro"].tap()
        XCTAssertTrue(app.staticTexts["Tutti i contenuti proposti"].waitForExistence(timeout: 5))
        app.buttons["Ricomincia"].tap()
        XCTAssertTrue(app.staticTexts["Nota di prova"].waitForExistence(timeout: 5))
    }
}

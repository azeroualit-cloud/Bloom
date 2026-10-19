import XCTest
import UIKit

final class DailyUseUITests: XCTestCase {
    @MainActor
    func testTagGridSquareContentAndConfirmedDeletion() {
        let (app, _) = captureNote(withCollection: false)
        returnToLibrary(app)
        let all = app.buttons["category-Tutti"]
        let unspecified = app.buttons["category-Da specificare"]
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        XCTAssertTrue(unspecified.exists)
        XCTAssertEqual(all.frame.minY, unspecified.frame.minY, accuracy: 2)
        XCTAssertGreaterThan(unspecified.frame.minX, all.frame.minX)
        XCTAssertEqual(all.frame.width, all.frame.height, accuracy: 2)
        XCTAssertFalse(app.segmentedControls.buttons["Archivio"].exists)
        unspecified.tap()
        let note = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-open-'")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertEqual(note.frame.width, note.frame.height, accuracy: 2)
        note.swipeLeft()
        XCTAssertTrue(app.buttons["Archivia"].waitForExistence(timeout: 5))
        app.buttons["Elimina"].tap()
        XCTAssertTrue(app.alerts.buttons["Annulla"].waitForExistence(timeout: 5), diagnostics(app))
        app.alerts.buttons["Annulla"].tap()
        XCTAssertTrue(note.exists)
        note.swipeLeft()
        app.buttons["Elimina"].tap()
        XCTAssertTrue(app.alerts.buttons["Elimina definitivamente"].waitForExistence(timeout: 5), diagnostics(app))
        app.alerts.buttons["Elimina definitivamente"].tap()
        XCTAssertTrue(app.staticTexts["Nessuna nota"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["library-count"].label, "0 contenuti")
    }

    @MainActor
    func testSecondaryMarkdownCanBeEditedAndReopened() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory", "--ui-test-attachments"]
        app.launch()
        XCTAssertTrue(app.buttons["category-Tutti"].waitForExistence(timeout: 15))
        app.buttons["category-Tutti"].tap()
        let note = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-open-'")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        note.tap()
        let attachment = app.buttons["note-file-secondary.md"]
        XCTAssertTrue(attachment.waitForExistence(timeout: 5), diagnostics(app))
        attachment.tap()
        XCTAssertTrue(app.buttons["Modifica"].waitForExistence(timeout: 5))
        app.buttons["Modifica"].tap()
        let editor = app.textViews["attachment-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap(); editor.typeText(" 123456")
        let expected = editor.value as? String
        app.buttons["attachment-save"].tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: editor)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(attachment.waitForExistence(timeout: 5))
        attachment.tap(); app.buttons["Modifica"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, expected)
        app.buttons["Annulla"].tap()
    }

    @MainActor
    func testDraftRestoresAcrossAppRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory", "--ui-test-drafts=\(UUID().uuidString)"]
        app.launch()
        XCTAssertTrue(app.buttons["capture-add"].waitForExistence(timeout: 15))
        app.buttons["capture-add"].tap()
        let body = app.textViews["capture-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["capture-close"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed, diagnostics(app))
        body.tap(); body.typeText("111222333")
        XCTAssertEqual(body.value as? String, "111222333", diagnostics(app))
        app.buttons["capture-close"].tap()
        app.buttons["Conserva bozza e chiudi"].tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["Nuova nota"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed, diagnostics(app))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["capture-add"].waitForExistence(timeout: 15))
        app.buttons["capture-add"].tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        let reloaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["capture-close"])
        XCTAssertEqual(XCTWaiter.wait(for: [reloaded], timeout: 10), .completed, diagnostics(app))
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '111222333'"), object: body)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed, diagnostics(app))
        app.buttons["capture-close"].tap()
        app.buttons["Scarta modifiche"].tap()
    }
    @MainActor
    func testQuickPasteSavesWithoutOpeningContent() {
        continueAfterFailure = false
        UIPasteboard.general.string = "https://example.com/quick-capture"
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory"]
        app.launch()
        XCTAssertTrue(app.buttons["capture-add"].waitForExistence(timeout: 15))
        app.buttons["capture-add"].tap()
        let paste = app.buttons["capture-paste-save"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5), diagnostics(app))
        paste.tap()
        XCTAssertTrue(app.buttons["library-open-saved"].waitForExistence(timeout: 10), diagnostics(app))
        XCTAssertFalse(app.navigationBars["Nuova nota"].exists)
        XCTAssertEqual(app.staticTexts["library-count"].label, "1 contenuti")
    }

    @MainActor
    func testSwipeArchiveUndoAndQuickTagEditing() {
        let (app, _) = captureNote(withCollection: false)
        returnToLibrary(app)
        app.buttons["category-Tutti"].tap()
        let note = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-open-'")).firstMatch
        note.swipeLeft()
        app.buttons["Archivia"].tap()
        XCTAssertTrue(app.staticTexts["library-count"].waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertEqual(app.staticTexts["library-count"].label, "0 contenuti")
        app.buttons["archive-undo"].tap()
        XCTAssertEqual(app.staticTexts["library-count"].label, "1 contenuti")
        app.buttons["library-back-tags"].tap()
        app.buttons["category-Da specificare"].tap()
        let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-actions-'")).firstMatch
        actions.tap()
        app.buttons["Modifica tag"].tap()
        app.buttons["tag-Salute"].tap()
        app.buttons["quick-tags-save"].tap()
        XCTAssertTrue(app.buttons["library-select"].waitForExistence(timeout: 5))
        app.buttons["library-back-tags"].tap()
        app.buttons["category-Salute"].tap()
        note.press(forDuration: 0.7)
        XCTAssertTrue(app.staticTexts["1 selezionati"].waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertFalse(app.navigationBars["Bloom test note"].exists, diagnostics(app))
    }

    @MainActor
    func testSaveAnotherAndDiscardProtectExistingNote() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory"]
        app.launch()
        XCTAssertTrue(app.buttons["capture-add"].waitForExistence(timeout: 15))
        app.buttons["capture-add"].tap()
        let text = app.textViews["capture-body"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap(); text.typeText("123456789")
        app.buttons["capture-keyboard-done"].tap()
        app.buttons["capture-save-another"].tap()
        XCTAssertTrue(app.navigationBars["Nuova nota"].exists)
        XCTAssertEqual(text.value as? String, "")
        text.tap(); text.typeText("987654321")
        app.buttons["capture-close"].tap()
        app.buttons["Scarta modifiche"].tap()
        XCTAssertTrue(app.buttons["library-select"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["library-count"].label, "1 contenuti")
    }
    @MainActor
    func testCaptureCollectionAndOpenPreserveInput() {
        let (app, _) = captureNote(withCollection: true)
        app.buttons["Dettagli"].tap()
        let collection = app.descendants(matching: .any)["detail-collection"].firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertEqual(collection.value as? String, "Salute · Studio", diagnostics(app))
    }

    @MainActor
    func testBulkArchiveAndRestore() {
        let (app, _) = captureNote(withCollection: false)
        returnToLibrary(app)
        app.buttons["library-select"].tap()
        app.buttons["bulk-select-all"].tap()
        app.buttons["bulk-archive-action"].tap()
        XCTAssertEqual(app.staticTexts["library-count"].label, "0 contenuti")
        app.buttons["library-settings"].tap()
        app.buttons["settings-archive"].tap()
        XCTAssertEqual(app.staticTexts["library-count"].label, "1 contenuti")
        app.buttons["bulk-select-all"].tap()
        app.buttons["bulk-archive-action"].tap()
        XCTAssertEqual(app.staticTexts["library-count"].label, "0 contenuti")
        app.buttons["library-settings"].tap()
        app.buttons["settings-archive"].tap()
        XCTAssertEqual(app.staticTexts["library-count"].label, "1 contenuti")
    }

    @MainActor
    func testRediscoveryExhaustionAndRestart() {
        let (app, title) = captureNote(withCollection: false)
        returnToLibrary(app)
        app.tabBars.buttons["Riscopri"].tap()
        let titleButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-title-'")).firstMatch
        XCTAssertTrue(titleButton.waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertEqual(titleButton.label, title)
        app.buttons["rediscovery-next"].tap()
        XCTAssertTrue(app.buttons["rediscovery-restart"].waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertFalse(titleButton.exists)
        app.buttons["rediscovery-restart"].tap()
        XCTAssertTrue(titleButton.waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertEqual(titleButton.label, title)
    }

    @MainActor
    private func captureNote(withCollection: Bool) -> (XCUIApplication, String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory"]
        app.launch()
        XCTAssertTrue(app.buttons["capture-add"].waitForExistence(timeout: 15))
        app.buttons["capture-add"].tap()
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
            let salute = app.buttons["tag-Salute"]
            if !salute.isHittable { app.swipeUp() }
            XCTAssertTrue(salute.waitForExistence(timeout: 5), diagnostics(app))
            salute.tap()
            app.buttons["tag-Studio"].tap()
        }
        XCTAssertTrue(app.buttons["capture-save"].waitForExistence(timeout: 5))
        app.buttons["capture-save"].tap()
        XCTAssertTrue(app.buttons["library-open-saved"].waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertFalse(app.navigationBars["Nuova nota"].exists, diagnostics(app))
        app.buttons["library-open-saved"].tap()
        XCTAssertTrue(app.navigationBars[enteredTitle].waitForExistence(timeout: 10), diagnostics(app))
        return (app, enteredTitle)
    }

    @MainActor
    private func returnToLibrary(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["library-select"].waitForExistence(timeout: 5), diagnostics(app))
    }

    @MainActor
    private func diagnostics(_ app: XCUIApplication) -> String {
        "Editors: \(app.textViews.allElementsBoundByIndex.map { ($0.identifier, $0.value as? String ?? "") }); Navigation: \(app.navigationBars.allElementsBoundByIndex.map(\.identifier)); texts: \(app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: ", ")); buttons: \(app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: ", "))"
    }
}

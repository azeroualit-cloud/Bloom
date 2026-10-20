import XCTest

final class DailyUseUITests: XCTestCase {
    @MainActor
    func testMapListsSavedPlaceAndOpensItsNote() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory", "--ui-test-map"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Mappa"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Mappa"].tap()
        let marker = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'map-marker-' ")).firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 10), diagnostics(app))
        marker.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'map-open-note-' ")).firstMatch.waitForExistence(timeout: 5), diagnostics(app))
        app.buttons["map-places-list"].tap()
        XCTAssertTrue(app.staticTexts["Colosseo"].waitForExistence(timeout: 5), diagnostics(app))
        app.buttons["Rome fixture"].tap()
        XCTAssertTrue(app.navigationBars["Rome fixture"].waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertTrue(app.buttons["note-edit-place"].exists)
    }

    @MainActor
    func testInstagramPhotoPostOpensInternalViewerWithRecoveryOptions() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory", "--ui-test-instagram"]
        app.launch()
        XCTAssertTrue(app.buttons["category-Tutti"].waitForExistence(timeout: 15))
        app.buttons["category-Tutti"].tap()
        openGridNote(app)
        app.buttons["note-link-open"].tap()
        XCTAssertTrue(app.buttons["instagram-view-options"].waitForExistence(timeout: 10), diagnostics(app))
        XCTAssertEqual(app.state, .runningForeground)
        app.buttons["instagram-view-options"].tap()
        XCTAssertTrue(app.buttons["Pagina Instagram in Bloom"].waitForExistence(timeout: 5))
        app.buttons["Pagina Instagram in Bloom"].tap()
        XCTAssertTrue(app.staticTexts["browser-address"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testNoteShowsBodyAndCarouselSwipesBetweenPhotos() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory", "--ui-test-carousel"]
        app.launch()
        XCTAssertTrue(app.buttons["category-Tutti"].waitForExistence(timeout: 15))
        app.buttons["category-Tutti"].tap()
        openGridNote(app)
        let carousel = app.otherElements["note-carousel"].firstMatch
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertEqual(carousel.frame.width / carousel.frame.height, 4.0 / 3.0, accuracy: 0.02)
        let position = app.staticTexts["carousel-position"]
        XCTAssertEqual(position.label, "1/2")
        XCTAssertFalse(app.buttons["note-file-second.png"].exists)
        let photo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'carousel-file-'")).firstMatch
        XCTAssertTrue(photo.exists)
        photo.tap()
        let original = app.scrollViews["image-original"]
        XCTAssertTrue(original.waitForExistence(timeout: 5), diagnostics(app))
        original.pinch(withScale: 2, velocity: 1)
        let zoomed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let value = original.value as? String ?? "0%"
            return (Int(value.replacingOccurrences(of: "%", with: "")) ?? 0) > 100
        }, object: original)
        XCTAssertEqual(XCTWaiter.wait(for: [zoomed], timeout: 5), .completed, diagnostics(app))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(position.waitForExistence(timeout: 5))
        carousel.swipeLeft()
        XCTAssertEqual(position.label, "2/2")
        XCTAssertTrue(app.staticTexts["Carousel text"].exists)
        carousel.swipeRight()
        XCTAssertEqual(position.label, "1/2")
    }

    @MainActor
    func testRenameFromPreviewMenuAndFullWidthRediscoveryFeed() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory", "--ui-test-browser"]
        app.launch()
        XCTAssertTrue(app.buttons["category-Tutti"].waitForExistence(timeout: 15))
        app.buttons["category-Tutti"].tap()
        let note = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-open-'" )).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.press(forDuration: 1.1)
        XCTAssertTrue(app.buttons["note-rename"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Archivia"].exists)
        app.buttons["note-rename"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let previous = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + "Updated title")
        app.alerts.buttons["Salva"].tap()
        XCTAssertEqual(note.label, "Updated title")
        app.tabBars.buttons["Riscopri"].tap()
        let carousel = app.otherElements["note-carousel"].firstMatch
        XCTAssertTrue(carousel.waitForExistence(timeout: 5))
        XCTAssertEqual(carousel.frame.width, app.frame.width, accuracy: 2)
        XCTAssertEqual(carousel.frame.width / carousel.frame.height, 3.0 / 4.0, accuracy: 0.02)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "Full width rediscovery feed"; image.lifetime = .keepAlways; add(image)
    }

    @MainActor
    func testCategoryCaptionsAndEdgeToEdgeThreeColumnGrid() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory", "--ui-test-grid"]
        app.launch()
        let all = app.buttons["category-Tutti"]
        XCTAssertTrue(all.waitForExistence(timeout: 15))
        XCTAssertTrue(all.label.contains("Tutti"))
        XCTAssertLessThan(all.frame.height, 80)
        let category = app.buttons["category-Casa"]
        XCTAssertTrue(category.exists)
        XCTAssertGreaterThan(category.frame.height, category.frame.width + 35)
        let home = XCTAttachment(screenshot: app.screenshot()); home.name = "Category covers with captions"; home.lifetime = .keepAlways; add(home)
        all.tap()
        let notes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-open-'"))
        XCTAssertTrue(notes.element(boundBy: 3).waitForExistence(timeout: 5), diagnostics(app))
        let frames = notes.allElementsBoundByIndex.map(\.frame).sorted {
            if abs($0.minY - $1.minY) > 2 { return $0.minY < $1.minY }
            return $0.minX < $1.minX
        }
        XCTAssertEqual(frames.count, 4)
        XCTAssertEqual(frames[0].minX, app.frame.minX, accuracy: 2)
        XCTAssertEqual(frames[0].width, app.frame.width / 3, accuracy: 2)
        XCTAssertEqual(frames[0].width, frames[0].height, accuracy: 2)
        XCTAssertEqual(frames[1].minX, frames[0].maxX, accuracy: 2)
        XCTAssertEqual(frames[2].minX, frames[1].maxX, accuracy: 2)
        XCTAssertEqual(frames[2].maxX, app.frame.maxX, accuracy: 2)
        XCTAssertEqual(frames[2].minY, frames[0].minY, accuracy: 2)
        XCTAssertEqual(frames[3].minY, frames[0].maxY, accuracy: 2)
        let grid = XCTAttachment(screenshot: app.screenshot()); grid.name = "Three columns without gutters"; grid.lifetime = .keepAlways; add(grid)
    }


    @MainActor
    func testDeletingFromRediscoveryClosesRetainedLibraryNote() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory", "--ui-test-browser"]
        app.launch()
        XCTAssertTrue(app.buttons["category-Tutti"].waitForExistence(timeout: 15))
        app.buttons["category-Tutti"].tap()
        openGridNote(app)
        XCTAssertTrue(app.navigationBars["Browser fixture"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Riscopri"].tap()
        XCTAssertTrue(app.otherElements["note-carousel"].firstMatch.waitForExistence(timeout: 5), diagnostics(app))
        let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-actions-'" )).firstMatch
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        actions.tap()
        XCTAssertTrue(app.buttons["Elimina"].waitForExistence(timeout: 5))
        app.buttons["Elimina"].tap()
        app.alerts.buttons["Sposta nel cestino"].tap()
        app.tabBars.buttons["Libreria"].tap()
        XCTAssertTrue(app.staticTexts["Nessuna nota"].waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertFalse(app.navigationBars["Browser fixture"].exists)
        XCTAssertEqual(app.staticTexts["library-count"].label, "0 contenuti")
    }

    @MainActor
    func testVisibleTagManagementRenamesAndDeletesWithoutDeletingNote() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory", "--ui-test-tags"]
        app.launch()
        XCTAssertTrue(app.buttons["library-settings"].waitForExistence(timeout: 15))
        app.buttons["library-settings"].tap()
        XCTAssertTrue(app.buttons["library-manage-tags"].waitForExistence(timeout: 5))
        app.buttons["library-manage-tags"].tap()
        XCTAssertTrue(app.buttons["tag-rename-Alimentazione"].waitForExistence(timeout: 5), diagnostics(app))
        app.buttons["tag-rename-Alimentazione"].tap()
        let field = app.textFields["collection-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Alimentazione".count) + "Alimenti")
        app.buttons["collection-save"].tap()
        XCTAssertTrue(app.buttons["tag-delete-Alimenti"].waitForExistence(timeout: 5), diagnostics(app))
        app.buttons["tag-delete-Alimenti"].tap()
        app.buttons["Elimina tag"].tap()
        XCTAssertFalse(app.buttons["tag-delete-Alimenti"].exists)
        app.buttons["tags-done"].tap()
        XCTAssertFalse(app.buttons["category-Alimenti"].exists)
        app.buttons["category-Tutti"].tap()
        openGridNote(app)
        XCTAssertTrue(app.navigationBars["Tag fixture"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Casa"].exists, diagnostics(app))
    }

    @MainActor
    func testLinkPreviewOpensNoteBeforeExplicitLinkTap() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory", "--ui-test-browser"]
        app.launch()
        XCTAssertTrue(app.buttons["category-Tutti"].waitForExistence(timeout: 15))
        app.buttons["category-Tutti"].tap()
        let note = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-open-'")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5), diagnostics(app))
        note.tap()
        let address = app.staticTexts["browser-address"]
        XCTAssertTrue(app.navigationBars["Browser fixture"].waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertTrue(app.staticTexts["note-detail-title"].exists)
        XCTAssertTrue(app.staticTexts["Body before opening the link"].exists)
        XCTAssertFalse(address.exists)
        app.buttons["note-link-open"].tap()
        XCTAssertTrue(address.waitForExistence(timeout: 10), diagnostics(app))
        XCTAssertEqual(address.label, "https://example.invalid/saved")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Riscopri"].tap()
        XCTAssertTrue(app.buttons["note-link-open"].waitForExistence(timeout: 5))
        app.buttons["note-link-open"].tap()
        XCTAssertTrue(app.staticTexts["note-detail-title"].waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertTrue(app.staticTexts["Body before opening the link"].exists)
        XCTAssertFalse(address.exists)
    }

    @MainActor
    func testTagGridSquareContentAndConfirmedDeletion() {
        let (app, _) = captureNote(withCollection: false)
        returnToLibrary(app)
        let all = app.buttons["category-Tutti"]
        let unspecified = app.buttons["category-Da specificare"]
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        XCTAssertTrue(unspecified.exists)
        XCTAssertLessThanOrEqual(all.frame.maxY, unspecified.frame.minY)
        XCTAssertLessThan(unspecified.frame.height, 80)
        XCTAssertLessThan(all.frame.height, 80)
        XCTAssertEqual(unspecified.frame.width, all.frame.width, accuracy: 2)
        XCTAssertFalse(app.segmentedControls.buttons["Archivio"].exists)
        unspecified.tap()
        let note = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-open-'")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertEqual(note.frame.width, note.frame.height, accuracy: 2)
        note.swipeLeft()
        XCTAssertTrue(app.buttons["Elimina"].waitForExistence(timeout: 5))
        app.buttons["Elimina"].tap()
        XCTAssertTrue(app.alerts.buttons["Annulla"].waitForExistence(timeout: 5), diagnostics(app))
        app.alerts.buttons["Annulla"].tap()
        XCTAssertTrue(note.exists)
        note.swipeLeft()
        app.buttons["Elimina"].tap()
        XCTAssertTrue(app.alerts.buttons["Sposta nel cestino"].waitForExistence(timeout: 5), diagnostics(app))
        app.alerts.buttons["Sposta nel cestino"].tap()
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
        XCTAssertTrue(app.navigationBars["Tutte le note"].waitForExistence(timeout: 5), diagnostics(app))
        let note = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-open-'")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        note.tap()
        let attachment = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'carousel-file-'")).firstMatch
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
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory", "--ui-test-clipboard"]
        app.launch()
        XCTAssertTrue(app.buttons["capture-add"].waitForExistence(timeout: 15))
        app.buttons["capture-add"].tap()
        let paste = app.buttons["capture-paste-save"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5), diagnostics(app))
        let pasteReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: paste)
        XCTAssertEqual(XCTWaiter.wait(for: [pasteReady], timeout: 10), .completed, diagnostics(app))
        XCTAssertEqual(app.buttons["capture-close"].value as? String, "clipboard-ready", diagnostics(app))
        let save = app.buttons["capture-save"]
        XCTAssertTrue(save.exists)
        XCTAssertFalse(save.isEnabled)
        XCTAssertGreaterThanOrEqual(paste.frame.minY, save.frame.maxY - 1, diagnostics(app))
        paste.tap()
        XCTAssertTrue(app.buttons["category-Tutti"].waitForExistence(timeout: 10), diagnostics(app))
        XCTAssertFalse(app.navigationBars["Nuova nota"].exists)
        XCTAssertEqual(app.staticTexts["library-count"].label, "1 contenuti")
    }

    @MainActor
    func testSwipeArchiveUndoAndQuickTagEditing() {
        let (app, _) = captureNote(withCollection: false)
        returnToLibrary(app)
        app.buttons["category-Tutti"].tap()
        XCTAssertTrue(app.navigationBars["Tutte le note"].waitForExistence(timeout: 5), diagnostics(app))
        let note = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-open-'")).firstMatch
        note.swipeLeft()
        app.buttons["Elimina"].tap()
        app.alerts.buttons["Sposta nel cestino"].tap()
        XCTAssertTrue(app.staticTexts["library-count"].waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertEqual(app.staticTexts["library-count"].label, "0 contenuti")
        app.buttons["archive-undo"].tap()
        XCTAssertEqual(app.staticTexts["library-count"].label, "1 contenuti")
        app.buttons["library-back-tags"].tap()
        app.buttons["category-Da specificare"].tap()
        note.press(forDuration: 1.1)
        XCTAssertTrue(app.buttons["note-context-tags"].waitForExistence(timeout: 5), diagnostics(app))
        app.buttons["note-context-tags"].tap()
        app.buttons["tag-Salute"].tap()
        app.buttons["quick-tags-save"].tap()
        XCTAssertTrue(app.buttons["library-select"].waitForExistence(timeout: 5))
        app.buttons["library-back-tags"].tap()
        app.buttons["category-Salute"].tap()
        note.press(forDuration: 1.1)
        XCTAssertTrue(app.buttons["note-context-select"].waitForExistence(timeout: 5), diagnostics(app))
        app.buttons["note-context-select"].tap()
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
        assertLibraryCount(app, count: 0)
        app.buttons["library-settings"].tap()
        app.buttons["settings-archive"].tap()
        assertLibraryCount(app, count: 1)
        app.buttons["bulk-select-all"].tap()
        app.buttons["bulk-archive-action"].tap()
        assertLibraryCount(app, count: 0)
        app.buttons["library-settings"].tap()
        app.buttons["settings-archive"].tap()
        assertLibraryCount(app, count: 1)
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
    private func openGridNote(_ app: XCUIApplication) {
        let note = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'note-open-'")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5), diagnostics(app))
        note.press(forDuration: 1.1)
        XCTAssertTrue(app.buttons["note-context-open"].waitForExistence(timeout: 5), diagnostics(app))
        app.buttons["note-context-open"].tap()
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
        XCTAssertTrue(app.buttons["category-Tutti"].waitForExistence(timeout: 5), diagnostics(app))
        XCTAssertFalse(app.navigationBars["Nuova nota"].exists, diagnostics(app))
        app.buttons["category-Tutti"].tap()
        openGridNote(app)
        XCTAssertTrue(app.navigationBars[enteredTitle].waitForExistence(timeout: 10), diagnostics(app))
        return (app, enteredTitle)
    }

    @MainActor
    private func returnToLibrary(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["library-select"].waitForExistence(timeout: 5), diagnostics(app))
        let back = app.buttons["library-back-tags"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), diagnostics(app))
        back.tap()
        XCTAssertTrue(app.buttons["category-Tutti"].waitForExistence(timeout: 5), diagnostics(app))
    }

    @MainActor
    private func assertLibraryCount(_ app: XCUIApplication, count: Int) {
        let expected = "\(count) contenuti"
        let condition = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", expected), object: app.staticTexts["library-count"])
        XCTAssertEqual(XCTWaiter.wait(for: [condition], timeout: 5), .completed, diagnostics(app))
    }

    @MainActor
    private func diagnostics(_ app: XCUIApplication) -> String {
        "Editors: \(app.textViews.allElementsBoundByIndex.map { ($0.identifier, $0.value as? String ?? "") }); Navigation: \(app.navigationBars.allElementsBoundByIndex.map(\.identifier)); texts: \(app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: ", ")); buttons: \(app.buttons.allElementsBoundByIndex.map { "\($0.label) [\($0.identifier)]" }.joined(separator: ", "))"
    }
}

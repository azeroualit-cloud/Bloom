import XCTest
import SwiftData
@testable import Bloom

@MainActor
final class NotePlaceTests: XCTestCase {
    private func container() throws -> ModelContainer {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return try LinkStore.container(at: root)
    }
    func testMapLinksExtractPinsButNotViewportCoordinatesOrSocialGuesses() throws {
        let apple = try XCTUnwrap(NotePlace.from(URL(string: "https://maps.apple.com/?ll=41.8902,12.4922&q=Colosseo")!))
        XCTAssertEqual(apple.name, "Colosseo")
        XCTAssertEqual(apple.latitude, 41.8902)
        XCTAssertNotNil(NotePlace.from(URL(string: "https://www.google.com/maps/search/?api=1&query=41.8902,12.4922")!))
        XCTAssertNil(NotePlace.from(URL(string: "https://www.google.com/maps/@41.8902,12.4922,12z")!))
        XCTAssertNil(NotePlace.from(URL(string: "https://maps.apple.com/?ll=999,12&q=Invalid")!))
        XCTAssertNil(NotePlace.from(URL(string: "https://maps.apple.com.evil.com/?ll=41,12")!))
        XCTAssertNil(NotePlace.from(URL(string: "https://www.instagram.com/p/rome/")!))
    }
    func testPlacePersistsThroughEditsDraftBackupAndExplicitRemoval() async throws {
        let source = try container(), context = source.mainContext
        let place = NotePlace(name: "Colosseo", latitude: 41.8902, longitude: 12.4922)
        let receipt = try LinkStore.saveNote(title: "Visit", body: "", urls: [], files: [], tags: [], location: .set(place), in: context)
        let note = try XCTUnwrap(context.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertEqual(note.id, receipt.id)
        _ = try LinkStore.saveNote(existing: note, title: "Visit later", body: "Body", urls: [], files: [], tags: [], in: context)
        XCTAssertEqual(note.place, place)
        let target = try container()
        _ = try BackupStore.restore(BackupStore.snapshot(from: source), into: target)
        XCTAssertEqual(try target.mainContext.fetch(FetchDescriptor<CapturedLink>()).first?.place, place)
        let draft = NoteDraft(title: "Visit", body: "", links: "", tags: [], files: [], place: place, placeEdited: true)
        XCTAssertEqual(try JSONDecoder().decode(NoteDraft.self, from: JSONEncoder().encode(draft)).place, place)
        _ = try LinkStore.saveNote(existing: note, title: "Visit later", body: "Body", urls: [], files: [], tags: [], location: .set(nil), in: context)
        XCTAssertNil(note.place)
        _ = try LinkStore.saveNote(existing: note, title: "Keep removed", body: "Body", urls: [URL(string: "https://maps.apple.com/?ll=41.8902,12.4922&q=Colosseo")!], files: [], tags: [], in: context)
        XCTAssertNil(note.place)
    }
    func testDirectMapCaptureAndTrashRetainCoordinates() throws {
        let source = try container(), context = source.mainContext
        _ = try LinkStore.capture(URL(string: "https://maps.apple.com/?ll=41.8902,12.4922&q=Colosseo")!, into: context)
        let note = try XCTUnwrap(context.fetch(FetchDescriptor<CapturedLink>()).first)
        let place = try XCTUnwrap(note.place)
        try LinkStore.setArchived(true, for: note, in: context)
        XCTAssertTrue(note.isArchived)
        XCTAssertEqual(note.place, place)
        try LinkStore.setArchived(false, for: note, in: context)
        XCTAssertEqual(note.place, place)
    }
}

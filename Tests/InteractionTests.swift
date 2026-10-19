import XCTest
import SwiftData
@testable import Bloom

final class InteractionTests: XCTestCase {
    private func root() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory
    }

    func testDraftSurvivesReopeningAndClosedSessionCannotResurrectIt() async throws {
        let directory = try root()
        let store = NoteDraftStore(directory: directory)
        let key = UUID(), session = UUID()
        let file = NoteFile(name: "note.md", type: "public.text", data: Data("# Content".utf8))
        let draft = NoteDraft(title: "Unfinished", body: "Some text", links: "https://example.com", tags: [UUID()], files: [file])
        try await store.save(draft, key: key, session: session)
        let reopened = NoteDraftStore(directory: directory)
        let restored = try await reopened.load(key)
        XCTAssertEqual(restored, draft)
        try await store.clear(key, session: session)
        try await store.save(draft, key: key, session: session)
        let cleared = try await store.load(key)
        XCTAssertNil(cleared)
        try await store.save(draft, key: nil, session: UUID())
        let separate = try await store.load(key)
        let newDraft = try await store.load(nil)
        XCTAssertNil(separate)
        XCTAssertEqual(newDraft, draft)
    }

    func testDelayedOlderDraftCannotReplaceNewerSnapshot() async throws {
        let store = NoteDraftStore(directory: try root())
        let session = UUID()
        let old = NoteDraft(title: "Old", body: "", links: "", tags: [], files: [])
        var current = old; current.title = "New"
        try await store.save(current, key: nil, session: session, revision: 2)
        try await store.save(old, key: nil, session: session, revision: 1)
        let restored = try await store.load(nil)
        XCTAssertEqual(restored?.title, "New")
        try await store.saveAndClose(current, key: nil, session: session, revision: 3)
        try await store.save(old, key: nil, session: session, revision: 4)
        let closed = try await store.load(nil)
        XCTAssertEqual(closed?.title, "New")
    }

    func testExplicitKeepCannotSilentlySucceedForClosedSession() async throws {
        let store = NoteDraftStore(directory: try root())
        let session = UUID()
        let draft = NoteDraft(title: "Kept", body: "Body", links: "", tags: [], files: [])
        try await store.saveAndClose(draft, key: nil, session: session, revision: 1)
        do {
            try await store.saveAndClose(draft, key: nil, session: session, revision: 2)
            XCTFail("A closed session must not report another successful keep")
        } catch is CancellationError { }
        let saved = try await store.load(nil)
        XCTAssertEqual(saved, draft)
    }

    func testClosingPreviousCaptureCannotDeleteNextDraft() async throws {
        let store = NoteDraftStore(directory: try root())
        let first = UUID(), next = UUID()
        let draft = NoteDraft(title: "Next", body: "", links: "", tags: [], files: [])
        try await store.save(draft, key: nil, session: next)
        try await store.clear(nil, session: first)
        let retained = try await store.load(nil, session: next)
        XCTAssertEqual(retained, draft)
        try await store.clear(nil, session: next)
        let discarded = try await store.load(nil)
        XCTAssertNil(discarded)
    }

    @MainActor
    func testBulkAddAndRemovePreserveOtherTagsAndRejectStaleTagsBeforeWriting() throws {
        let container = try LinkStore.container(at: root())
        let context = container.mainContext
        let first = try LinkStore.saveCollection(nil, name: "First", in: context)
        let second = try LinkStore.saveCollection(nil, name: "Second", in: context)
        let third = try LinkStore.saveCollection(nil, name: "Third", in: context)
        _ = try LinkStore.saveNote(title: "A", body: "", urls: [], files: [], tags: [first.id], in: context)
        _ = try LinkStore.saveNote(title: "B", body: "", urls: [], files: [], tags: [third.id], in: context)
        let items = try context.fetch(FetchDescriptor<CapturedLink>())
        try LinkStore.setTags([second.id], for: items, mode: .add, in: context)
        XCTAssertEqual(items.first { $0.title == "A" }?.tagIDs, [first.id, second.id])
        XCTAssertEqual(items.first { $0.title == "B" }?.tagIDs, [third.id, second.id])
        try LinkStore.setTags([second.id], for: items, mode: .remove, in: context)
        XCTAssertEqual(items.first { $0.title == "A" }?.tagIDs, [first.id])
        XCTAssertEqual(items.first { $0.title == "B" }?.tagIDs, [third.id])
        XCTAssertThrowsError(try LinkStore.setTags([second.id, UUID()], for: items, mode: .replace, in: context))
        XCTAssertEqual(items.first { $0.title == "A" }?.tagIDs, [first.id])
        XCTAssertEqual(items.first { $0.title == "B" }?.tagIDs, [third.id])
    }
}

import XCTest
import SwiftData
@testable import Bloom

@MainActor
final class ArchiveReadinessTests: XCTestCase {
    private func container() throws -> ModelContainer {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return try LinkStore.container(at: url)
    }
    func testTagRenameAndDeletionPersistWithoutChangingNotesOrOtherTags() throws {
        let source = try container(), context = source.mainContext
        let tag = try LinkStore.saveCollection(nil, name: "Alimentazione", in: context)
        let other = try LinkStore.saveCollection(nil, name: "Casa", in: context)
        let tagID = tag.id, otherID = other.id
        let receipt = try LinkStore.saveNote(title: "Keep", body: "Original body", urls: [], files: [], tags: [tagID, otherID], in: context)
        _ = try LinkStore.saveCollection(tag, name: "Alimenti", in: context)
        let renamed = ModelContext(source)
        XCTAssertEqual(try renamed.fetch(FetchDescriptor<LinkCollection>()).first { $0.id == tagID }?.name, "Alimenti")
        XCTAssertEqual(try renamed.fetch(FetchDescriptor<CapturedLink>()).first?.tagIDs, [tagID, otherID])
        try LinkStore.deleteCollection(tag, in: context)
        let check = ModelContext(source)
        let note = try XCTUnwrap(check.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertEqual(note.id, receipt.id)
        XCTAssertEqual(note.tagIDs, [otherID])
        XCTAssertEqual(note.noteBody, "Original body")
        XCTAssertEqual(try check.fetch(FetchDescriptor<LinkCollection>()).map(\.id), [otherID])
    }
    func testDeletingNotePreservesSharedTagsAndOtherNotesAfterReopen() throws {
        let source = try container(), context = source.mainContext
        let tag = try LinkStore.saveCollection(nil, name: "Studio", in: context)
        _ = try LinkStore.saveNote(title: "First", body: "", urls: [], files: [], tags: [tag.id], in: context)
        _ = try LinkStore.saveNote(title: "Second", body: "", urls: [], files: [], tags: [tag.id], in: context)
        let first = try XCTUnwrap(context.fetch(FetchDescriptor<CapturedLink>()).first { $0.title == "First" })
        try LinkStore.deleteNote(first, in: context)
        let check = ModelContext(source)
        let notes = try check.fetch(FetchDescriptor<CapturedLink>())
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.title, "Second")
        XCTAssertEqual(notes.first?.tagIDs, [tag.id])
        XCTAssertEqual(try check.fetch(FetchDescriptor<LinkCollection>()).count, 1)
    }
    func testSecondaryDocumentEditsAndImageFramingSurviveFullRestore() throws {
        let source = try container(), context = source.mainContext
        let text = NoteFile(name: "note.md", type: "public.text", data: Data("# Old".utf8))
        let image = NoteFile(name: "screen.png", type: "public.png", data: Data([1, 2, 3]))
        _ = try LinkStore.saveNote(title: "Files", body: "Body", urls: [URL(string: "https://example.com")!], files: [text, image], tags: [], in: context)
        let note = try XCTUnwrap(context.fetch(FetchDescriptor<CapturedLink>()).first)
        try LinkStore.updateNoteFile(NoteFile(id: text.id, name: text.name, type: text.type, data: Data("# Edited".utf8)), for: note, in: context)
        var framed = image; framed.framing = ImageFraming(top: 0.15, bottom: 0.1)
        try LinkStore.updateNoteFile(framed, for: note, in: context)
        let target = try container()
        let backup = try LibraryBackup.decode(BackupStore.snapshot(from: source).encoded())
        _ = try BackupStore.restore(backup, into: target)
        let restored = try XCTUnwrap(target.mainContext.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertEqual(restored.noteFiles[0].data, Data("# Edited".utf8))
        XCTAssertEqual(restored.noteFiles[1].framing, framed.framing)
        XCTAssertEqual(restored.noteFiles[1].data, image.data)
        var invalid = framed; invalid.framing = ImageFraming(top: 0.8, bottom: 0.8)
        XCTAssertThrowsError(try LinkStore.updateNoteFile(invalid, for: note, in: context))
        XCTAssertEqual(note.noteFiles[1].framing, framed.framing)
    }
    func testPrimaryBytesAndAttachmentCountAreIncludedBeforeMutation() throws {
        let source = try container(), context = source.mainContext
        let large = NoteFile(name: "large.bin", type: "public.data", data: Data(repeating: 1, count: AttachmentLoader.maximumBytes - 4))
        _ = try LinkStore.saveNote(title: "Original", body: "", urls: [], files: [large], tags: [], in: context)
        let note = try XCTUnwrap(context.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertThrowsError(try LinkStore.saveNote(existing: note, title: "Changed", body: "12345", urls: [], files: [], tags: [], in: context))
        XCTAssertEqual(note.title, "Original")
        let urls = (0..<10).map { URL(string: "https://example.com/\($0)")! }
        XCTAssertThrowsError(try LinkStore.saveNote(existing: note, title: "Changed", body: "", urls: urls, files: [], tags: [], in: context))
        XCTAssertEqual(note.title, "Original")
    }
    func testThousandNotesRoundTripAndRepeatedRestoreIsIdempotent() throws {
        let source = try container(), context = source.mainContext
        for index in 0..<1000 {
            let note = CapturedLink(kind: .text)
            note.title = "Note \(index)"; note.textContent = "# Body \(index)"; note.noteVersion = 1
            note.isArchived = index % 5 == 0
            context.insert(note)
        }
        try context.save()
        let backup = try LibraryBackup.decode(BackupStore.snapshot(from: source).encoded())
        let target = try container()
        XCTAssertEqual(try BackupStore.restore(backup, into: target).added, 1000)
        XCTAssertEqual(try BackupStore.restore(backup, into: target).skipped, 1000)
        let notes = try target.mainContext.fetch(FetchDescriptor<CapturedLink>())
        XCTAssertEqual(notes.filter(\.isArchived).count, 200)
        XCTAssertTrue(notes.contains { $0.textContent == "# Body 999" })
    }
    func testDuplicateLinksHaveStableUniqueIdentityAndLegacyFilesDecode() throws {
        let file = try JSONDecoder().decode(NoteFile.self, from: Data("{\"id\":\"00000000-0000-0000-0000-000000000001\",\"name\":\"old.md\",\"type\":\"public.text\",\"data\":\"IyBPbGQ=\"}".utf8))
        XCTAssertNil(file.framing)
        let source = try container(), context = source.mainContext
        let url = URL(string: "https://example.com")!
        _ = try LinkStore.saveNote(title: "Links", body: "", urls: [url, url], files: [], tags: [], in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CapturedLink>()).first?.allLinks, [url])
    }
}

import XCTest
import SwiftData
@testable import Bloom

@MainActor
final class NoteArchiveTests: XCTestCase {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    func testNoteWithMultipleTagsLinksAndFilesSurvivesBackupAndReopen() throws {
        let directory = try root()
        let container = try LinkStore.container(at: directory)
        let context = container.mainContext
        try LinkStore.initializeTags(in: context)
        let tags = try context.fetch(FetchDescriptor<LinkCollection>())
        XCTAssertEqual(Set(tags.map(\.name)), Set(NoteTags.initial))
        let selected = Set(tags.filter { ["Salute", "Studio"].contains($0.name) }.map(\.id))
        let urls = [URL(string: "https://www.youtube.com/watch?v=abc")!, URL(string: "https://www.instagram.com/reel/abc/")!]
        let file = NoteFile(name: "nota.md", type: "net.daringfireball.markdown", data: Data("# Allegato".utf8))
        let receipt = try LinkStore.saveNote(title: "Mobilità", body: "## Routine\n\nOgni mattina", urls: urls, files: [file], tags: selected, in: context)
        let backup = try LibraryBackup.decode(BackupStore.snapshot(from: container).encoded())
        XCTAssertEqual(backup.version, 2)
        let restored = try LinkStore.container(at: root())
        _ = try BackupStore.restore(backup, into: restored)
        let note = try XCTUnwrap(restored.mainContext.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertEqual(note.id, receipt.id)
        XCTAssertEqual(note.tagIDs, selected)
        XCTAssertEqual(note.allLinks, urls)
        XCTAssertEqual(note.noteFiles.first?.data, file.data)
        XCTAssertEqual(note.noteBody, "## Routine\n\nOgni mattina")
        XCTAssertEqual(try BackupStore.restore(backup, into: restored).added, 0)
        let reopened = try LinkStore.container(at: directory)
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<CapturedLink>()).first?.tagIDs, selected)
    }

    func testLegacyCollectionBecomesTagAndDeletingOneTagKeepsOther() throws {
        let container = try LinkStore.container(at: root())
        let context = container.mainContext
        let old = try LinkStore.saveCollection(nil, name: "Vecchie idee", in: context)
        let receipt = try LinkStore.captureLink(URL(string: "https://example.com/old")!, collectionID: old.id, into: context)
        try LinkStore.initializeTags(in: context)
        let item = try XCTUnwrap(context.fetch(FetchDescriptor<CapturedLink>()).first { $0.id == receipt.id })
        XCTAssertEqual(item.tagIDs, [old.id])
        let new = try LinkStore.saveCollection(nil, name: "Nuovo", in: context)
        try LinkStore.setTags([old.id, new.id], for: [item], in: context)
        try LinkStore.deleteCollection(old, in: context)
        XCTAssertEqual(item.tagIDs, [new.id])
        XCTAssertTrue(LibraryFilter.matches(item, search: "", archived: false, collection: .collection(new.id)))
    }

    func testUnspecifiedTitleOnlyAndInvalidTagAreAtomic() throws {
        let container = try LinkStore.container(at: root())
        let context = container.mainContext
        _ = try LinkStore.saveNote(title: "Una idea", body: "", urls: [], files: [], tags: [], in: context)
        let item = try XCTUnwrap(context.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertTrue(item.tagIDs.isEmpty)
        XCTAssertTrue(LibraryFilter.matches(item, search: "", archived: false, collection: .unfiled))
        XCTAssertNoThrow(try BackupStore.snapshot(from: container).encoded())
        XCTAssertThrowsError(try LinkStore.saveNote(existing: item, title: "Modificato", body: "", urls: [], files: [], tags: [UUID()], in: context))
        XCTAssertEqual(item.title, "Una idea")
        XCTAssertThrowsError(try LinkStore.saveNote(title: "", body: "", urls: [], files: [], tags: [], in: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CapturedLink>()), 1)
    }

    func testVideoHostsAndSingleWordTagValidation() throws {
        XCTAssertTrue(SocialLink.isVideo(URL(string: "https://youtu.be/abc")!))
        XCTAssertTrue(SocialLink.isVideo(URL(string: "https://vm.tiktok.com/abc")!))
        XCTAssertTrue(SocialLink.isVideo(URL(string: "https://www.instagram.com/reel/abc")!))
        XCTAssertFalse(SocialLink.isVideo(URL(string: "https://youtube.com.evil.example/abc")!))
        XCTAssertFalse(SocialLink.isVideo(URL(string: "https://www.instagram.com/p/abc")!))
        XCTAssertEqual(try NoteTags.validate(" Salute "), "Salute")
        XCTAssertThrowsError(try NoteTags.validate("Due parole"))
        XCTAssertThrowsError(try NoteTags.validate("Da specificare"))
    }
}

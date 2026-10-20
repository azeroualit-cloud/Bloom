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

    func testOrderedMixedAttachmentsAndActivitySurviveRestore() throws {
        let source = try LinkStore.container(at: root()), context = source.mainContext
        let first = try LinkStore.saveCollection(nil, name: "Casa", in: context)
        let second = try LinkStore.saveCollection(nil, name: "Studio", in: context)
        let files = [NoteFile(name: "one.png", type: "public.png", data: Data([1, 2])),
                     NoteFile(name: "clip.mov", type: "com.apple.quicktime-movie", data: Data([3, 4])),
                     NoteFile(name: "note.md", type: "public.text", data: Data("# Hello".utf8))]
        _ = try LinkStore.saveNote(title: "Mixed", body: "Caption", urls: [], files: files, tags: [first.id], in: context)
        let note = try XCTUnwrap(context.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertEqual(note.fileName, "one.png")
        XCTAssertEqual(note.noteFiles.map(\.id), Array(files.dropFirst()).map(\.id))
        let old = Date(timeIntervalSince1970: 1)
        first.modifiedAt = old; second.modifiedAt = old; note.modifiedAt = old
        try context.save()
        try LinkStore.setTags([second.id], for: [note], in: context)
        XCTAssertGreaterThan(try XCTUnwrap(first.modifiedAt), old)
        XCTAssertGreaterThan(try XCTUnwrap(second.modifiedAt), old)
        XCTAssertGreaterThan(try XCTUnwrap(note.modifiedAt), old)
        let backup = try LibraryBackup.decode(BackupStore.snapshot(from: source).encoded())
        let target = try LinkStore.container(at: root())
        _ = try BackupStore.restore(backup, into: target)
        let restored = try XCTUnwrap(target.mainContext.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertEqual(restored.modifiedAt, note.modifiedAt)
        XCTAssertEqual(restored.noteFiles, note.noteFiles)
        XCTAssertEqual(restored.attachmentData, files[0].data)
        XCTAssertEqual(restored.noteBody, "Caption")
    }

    func testAllSocialPostsUseAppOpeningWithoutHostSpoofing() {
        XCTAssertFalse(SocialLink.opensInApp(URL(string: "https://www.instagram.com/p/abc/")!))
        XCTAssertTrue(SocialLink.opensInApp(URL(string: "https://www.instagram.com/reel/abc/")!))
        XCTAssertFalse(SocialLink.isVideo(URL(string: "https://www.instagram.com/p/abc/")!))
        XCTAssertFalse(SocialLink.opensInApp(URL(string: "https://evilinstagram.com/p/abc/")!))
        XCTAssertFalse(SocialLink.opensInApp(URL(string: "https://instagram.com.example.com/p/abc/")!))
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
        XCTAssertEqual(note.noteFileCount, 1)
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

    func testDistinctNotesAboutSameVideoAreNotDroppedOnRestore() throws {
        let source = try LinkStore.container(at: root())
        let url = URL(string: "https://youtu.be/same-video")!
        _ = try LinkStore.saveNote(title: "Prima", body: "Prima osservazione", urls: [url], files: [], tags: [], in: source.mainContext)
        _ = try LinkStore.saveNote(title: "Seconda", body: "Seconda osservazione", urls: [url], files: [], tags: [], in: source.mainContext)
        _ = try LinkStore.saveNote(title: "Solo un titolo", body: "", urls: [url], files: [], tags: [], in: source.mainContext)
        let target = try LinkStore.container(at: root())
        let backup = try LibraryBackup.decode(BackupStore.snapshot(from: source).encoded())
        XCTAssertEqual(try BackupStore.restore(backup, into: target).added, 3)
        XCTAssertEqual(try BackupStore.restore(backup, into: target).added, 0)
    }

    func testImageFramingChangesPresentationAndPreservesOriginalInBackup() throws {
        let source = try LinkStore.container(at: root())
        let original = Data([1, 2, 3, 4])
        let file = NoteFile(name: "screenshot.png", type: "public.png", data: original)
        _ = try LinkStore.saveNote(title: "", body: "", urls: [], files: [file], tags: [], in: source.mainContext)
        let item = try XCTUnwrap(source.mainContext.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertEqual(item.kind, .image)
        let framing = ImageFraming(top: 0.15, bottom: 0.2, left: 0, right: 0)
        try LinkStore.setImageFraming(framing, for: item, in: source.mainContext)
        XCTAssertEqual(item.attachmentData, original)
        let target = try LinkStore.container(at: root())
        _ = try BackupStore.restore(LibraryBackup.decode(BackupStore.snapshot(from: source).encoded()), into: target)
        let restored = try XCTUnwrap(target.mainContext.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertEqual(restored.imageFraming, framing)
        XCTAssertEqual(restored.attachmentData, original)
        XCTAssertThrowsError(try LinkStore.setImageFraming(ImageFraming(top: 0.7, bottom: 0.7), for: item, in: source.mainContext))
        XCTAssertEqual(item.imageFraming, framing)
    }

    func testPreviousBackupWithoutNoteFieldsStillImports() throws {
        var backup = LibraryBackup(collections: [], items: [
            .init(id: UUID(), kind: "link", capturedAt: .now, urlString: "https://example.com/old", title: "Vecchio", notes: nil, archived: false, collectionID: nil, text: nil, fileName: nil, contentType: nil, data: nil)
        ])
        backup.version = 1
        let data = try backup.encoded()
        let target = try LinkStore.container(at: root())
        XCTAssertEqual(try BackupStore.restore(LibraryBackup.decode(data), into: target).added, 1)
    }

    func testRestoreMapsTagsOntoAnAlreadyInitializedLibrary() throws {
        let source = try LinkStore.container(at: root())
        try LinkStore.initializeTags(in: source.mainContext)
        let sourceTag = try XCTUnwrap(source.mainContext.fetch(FetchDescriptor<LinkCollection>()).first { $0.name == "Salute" })
        _ = try LinkStore.saveNote(title: "Nota", body: "Testo", urls: [], files: [], tags: [sourceTag.id], in: source.mainContext)
        let target = try LinkStore.container(at: root())
        try LinkStore.initializeTags(in: target.mainContext)
        let targetTag = try XCTUnwrap(target.mainContext.fetch(FetchDescriptor<LinkCollection>()).first { $0.name == "Salute" })
        XCTAssertNotEqual(sourceTag.id, targetTag.id)
        _ = try BackupStore.restore(BackupStore.snapshot(from: source), into: target)
        let fresh = ModelContext(target)
        let note = try XCTUnwrap(fresh.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertEqual(note.tagIDs, [targetTag.id])
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<LinkCollection>()), NoteTags.initial.count)
    }
}

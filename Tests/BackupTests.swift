import XCTest
import SwiftData
@testable import Bloom

final class BackupTests: XCTestCase {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    private func record(id: UUID = UUID(), url: String = "https://example.com/backup", collection: UUID? = nil) -> LibraryBackup.Item {
        .init(id: id, kind: "link", capturedAt: Date(timeIntervalSince1970: 1234.5), urlString: url,
              title: "Dal backup", notes: "Note importate", archived: true, collectionID: collection,
              text: nil, fileName: nil, contentType: nil, data: nil)
    }

    @MainActor
    func testRoundTripAllFormatsCollectionsAndArchiveAcrossReopen() throws {
        let source = try LinkStore.container(at: root())
        let context = source.mainContext
        try LinkStore.capture(URL(string: "https://example.com/test")!, into: context)
        try LinkStore.captureText("# Appunti\nTesto completo", title: "Nota", into: context)
        let image = Data([1, 2, 3, 4])
        let file = Data("# Documento markdown".utf8)
        try LinkStore.captureAttachment(.init(data: image, name: "foto.png", type: "public.png", kind: .image), into: context)
        try LinkStore.captureAttachment(.init(data: file, name: "nota.md", type: "net.daringfireball.markdown", kind: .file), into: context)
        let collection = try LinkStore.saveCollection(nil, name: "Idee", in: context)
        let items = try context.fetch(FetchDescriptor<CapturedLink>())
        for item in items {
            try LinkStore.update(item, title: item.displayTitle, notes: "Note personali", collection: collection, in: context)
        }
        try LinkStore.setArchived(true, for: items[0], in: context)
        let backup = try BackupStore.snapshot(from: source)
        let decoded = try LibraryBackup.decode(backup.encoded())
        XCTAssertEqual(decoded.items.count, 4)
        let targetRoot = try root()
        do {
            let target = try LinkStore.container(at: targetRoot)
            let result = try BackupStore.restore(decoded, into: target)
            XCTAssertEqual(result.added, 4)
            XCTAssertEqual(result.skipped, 0)
            XCTAssertEqual(result.collectionsAdded, 1)
            let repeatResult = try BackupStore.restore(decoded, into: target)
            XCTAssertEqual(repeatResult.added, 0)
            XCTAssertEqual(repeatResult.skipped, 4)
            XCTAssertEqual(repeatResult.collectionsAdded, 0)
        }
        let reopened = try LinkStore.container(at: targetRoot)
        let restored = try reopened.mainContext.fetch(FetchDescriptor<CapturedLink>())
        XCTAssertEqual(Set(restored.map(\.id)), Set(items.map(\.id)))
        XCTAssertEqual(restored.filter(\.isArchived).count, 1)
        XCTAssertTrue(restored.allSatisfy { $0.notes == "Note personali" && $0.collection?.id == collection.id })
        XCTAssertEqual(restored.first { $0.kind == .image }?.attachmentData, image)
        XCTAssertEqual(restored.first { $0.kind == .file }?.attachmentData, file)
        XCTAssertEqual(restored.first { $0.kind == .text }?.textContent, "# Appunti\nTesto completo")
        for item in restored {
            let original = try XCTUnwrap(items.first { $0.id == item.id })
            XCTAssertEqual(item.capturedAt, original.capturedAt)
            XCTAssertEqual(item.title, original.title)
        }
    }

    @MainActor
    func testMergeKeepsExistingMetadataAndMatchesCollectionName() throws {
        let target = try LinkStore.container(at: root())
        let context = target.mainContext
        try LinkStore.capture(URL(string: "https://example.com/backup")!, into: context)
        let current = try XCTUnwrap(context.fetch(FetchDescriptor<CapturedLink>()).first)
        let collection = try LinkStore.saveCollection(nil, name: "Caffè", in: context)
        try LinkStore.update(current, title: "Titolo attuale", notes: "Non sovrascrivere", collection: collection, in: context)
        let backupCollectionID = UUID()
        let backup = LibraryBackup(collections: [
            .init(id: backupCollectionID, name: " CAFFE ", createdAt: .now)
        ], items: [record(collection: backupCollectionID), record(url: "https://example.com/new", collection: backupCollectionID)])
        let result = try BackupStore.restore(backup, into: target)
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.collectionsAdded, 0)
        let fresh = ModelContext(target)
        let items = try fresh.fetch(FetchDescriptor<CapturedLink>())
        let preserved = try XCTUnwrap(items.first { $0.id == current.id })
        XCTAssertEqual(preserved.title, "Titolo attuale")
        XCTAssertEqual(preserved.notes, "Non sovrascrivere")
        XCTAssertFalse(preserved.isArchived)
        XCTAssertTrue(items.allSatisfy { $0.collection?.id == collection.id })
    }

    @MainActor
    func testDeduplicatesTextAndFilesByBytesDespiteDifferentIDs() throws {
        let source = try LinkStore.container(at: root())
        try LinkStore.captureText("Testo", title: "Source", into: source.mainContext)
        let payload = AttachmentPayload(data: Data([1, 2, 3]), name: "file.bin", type: "public.data", kind: .file)
        try LinkStore.captureAttachment(payload, into: source.mainContext)
        let target = try LinkStore.container(at: root())
        try LinkStore.captureText("Testo", title: "Target", into: target.mainContext)
        try LinkStore.captureAttachment(payload, into: target.mainContext)
        let result = try BackupStore.restore(BackupStore.snapshot(from: source), into: target)
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.skipped, 2)
        XCTAssertEqual(try target.mainContext.fetchCount(FetchDescriptor<CapturedLink>()), 2)
    }

    @MainActor
    func testInvalidBackupWritesNothingAndPreservesPendingChanges() throws {
        let target = try LinkStore.container(at: root())
        let pending = CapturedLink(url: URL(string: "https://example.com/pending")!)
        target.mainContext.insert(pending)
        let bad = LibraryBackup(collections: [], items: [record(), record(collection: UUID())])
        XCTAssertThrowsError(try BackupStore.restore(bad, into: target))
        XCTAssertTrue(target.mainContext.hasChanges)
        XCTAssertEqual(try ModelContext(target).fetchCount(FetchDescriptor<CapturedLink>()), 0)
    }

    func testRejectsCorruptFutureVersionDuplicateIDsAndNonWebLinks() throws {
        XCTAssertThrowsError(try LibraryBackup.decode(Data("not JSON".utf8)))
        var future = LibraryBackup(collections: [], items: [])
        future.version = 2
        XCTAssertThrowsError(try future.validated())
        let item = record()
        XCTAssertThrowsError(try LibraryBackup(collections: [], items: [item, item]).validated())
        XCTAssertThrowsError(try LibraryBackup(collections: [], items: [record(url: "file:///etc/passwd")]).validated())
        let wrongKind = LibraryBackup.Item(id: UUID(), kind: "future", capturedAt: .now, urlString: "",
            title: nil, notes: nil, archived: false, collectionID: nil, text: nil, fileName: nil, contentType: nil, data: nil)
        XCTAssertThrowsError(try LibraryBackup(collections: [], items: [wrongKind]).validated())
    }

    func testReadsCoordinatedFileAndRejectsOversizedFileBeforeLoading() throws {
        let directory = try root()
        let url = directory.appendingPathComponent("backup.json")
        let backup = LibraryBackup(collections: [], items: [record()])
        try backup.encoded().write(to: url)
        XCTAssertEqual(try LibraryBackup.read(url).items.count, 1)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(LibraryBackup.maximumFileBytes + 1))
        try handle.close()
        XCTAssertThrowsError(try LibraryBackup.read(url))
    }

    func testRejectsOversizedIndividualAndAggregatePayloads() {
        let data = Data(repeating: 1, count: AttachmentLoader.maximumBytes)
        func attachment(_ data: Data) -> LibraryBackup.Item {
            .init(id: UUID(), kind: "file", capturedAt: .now, urlString: "", title: nil, notes: nil,
                  archived: false, collectionID: nil, text: nil, fileName: "file", contentType: "public.data", data: data)
        }
        XCTAssertThrowsError(try LibraryBackup(collections: [], items: [attachment(data + Data([1]))]).validated())
        XCTAssertThrowsError(try LibraryBackup(collections: [], items: [attachment(data), attachment(data), attachment(data)]).validated())
    }
}

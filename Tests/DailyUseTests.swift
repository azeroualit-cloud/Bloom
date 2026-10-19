import XCTest
import SwiftData
@testable import Bloom

final class DailyUseTests: XCTestCase {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    @MainActor
    func testOrganizedCaptureAndDuplicateReceiptsPersist() throws {
        let directory = try root()
        let container = try LinkStore.container(at: directory)
        let context = container.mainContext
        let collection = try LinkStore.saveCollection(nil, name: "Da provare", in: context)
        let url = URL(string: "https://example.com/capture")!
        let link = try LinkStore.captureLink(url, title: " Ricetta ", collectionID: collection.id, into: context)
        let duplicate = try LinkStore.captureLink(url, title: "Non sovrascrivere", into: context)
        XCTAssertTrue(link.inserted)
        XCTAssertFalse(duplicate.inserted)
        XCTAssertEqual(link.id, duplicate.id)
        let text = try LinkStore.captureTextItem("Appunto", title: "Nota", collectionID: collection.id, into: context)
        let payload = AttachmentPayload(data: Data([1, 2]), name: "file.bin", type: "public.data", kind: .file)
        let file = try LinkStore.captureAttachmentItem(payload, collectionID: collection.id, into: context)
        XCTAssertEqual(try LinkStore.captureTextItem("Appunto", title: "Altro", into: context).id, text.id)
        XCTAssertEqual(try LinkStore.captureAttachmentItem(payload, into: context).id, file.id)
        let fresh = try LinkStore.container(at: directory)
        let items = try fresh.mainContext.fetch(FetchDescriptor<CapturedLink>())
        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.allSatisfy { $0.collection?.id == collection.id })
        XCTAssertEqual(items.first { $0.id == link.id }?.title, "Ricetta")
    }

    @MainActor
    func testMissingCollectionCannotPartiallyCaptureOrMoveSelection() throws {
        let container = try LinkStore.container(at: root())
        let context = container.mainContext
        XCTAssertThrowsError(try LinkStore.captureLink(URL(string: "https://example.com")!, collectionID: UUID(), into: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CapturedLink>()), 0)
        let first = try LinkStore.captureLink(URL(string: "https://example.com/1")!, into: context)
        let second = try LinkStore.captureLink(URL(string: "https://example.com/2")!, into: context)
        XCTAssertThrowsError(try LinkStore.apply(.archived(true), to: [first.id, UUID()], in: context))
        XCTAssertThrowsError(try LinkStore.apply(.collection(UUID()), to: [first.id, second.id], in: context))
        XCTAssertTrue(try context.fetch(FetchDescriptor<CapturedLink>()).allSatisfy { !$0.isArchived && $0.collection == nil })
    }

    @MainActor
    func testBulkMoveArchiveRestoreAndUnfilePersistWithoutTouchingUnselected() throws {
        let directory = try root()
        let container = try LinkStore.container(at: directory)
        let context = container.mainContext
        let collection = try LinkStore.saveCollection(nil, name: "Progetti", in: context)
        let receipts = try (1...3).map { try LinkStore.captureLink(URL(string: "https://example.com/\($0)")!, into: context) }
        let selected = Set(receipts.prefix(2).map(\.id))
        XCTAssertEqual(try LinkStore.apply(.collection(collection.id), to: selected, in: context), 2)
        XCTAssertEqual(try LinkStore.apply(.archived(true), to: selected, in: context), 2)
        let reopened = try LinkStore.container(at: directory)
        let items = try reopened.mainContext.fetch(FetchDescriptor<CapturedLink>())
        XCTAssertTrue(items.filter { selected.contains($0.id) }.allSatisfy { $0.isArchived && $0.collection?.id == collection.id })
        XCTAssertTrue(items.filter { !selected.contains($0.id) }.allSatisfy { !$0.isArchived && $0.collection == nil })
        try LinkStore.apply(.archived(false), to: selected, in: reopened.mainContext)
        try LinkStore.apply(.collection(nil), to: selected, in: reopened.mainContext)
        XCTAssertTrue(items.allSatisfy { !$0.isArchived && $0.collection == nil })
    }

    @MainActor
    func testFormatFiltersCombineWithCollectionSearchAndArchive() {
        let item = CapturedLink(kind: .text)
        item.textContent = "Caffè"
        let collection = LinkCollection(name: "Idee")
        item.collection = collection
        XCTAssertTrue(LibraryFilter.matches(item, search: "caffe", archived: false, collection: .collection(collection.id), kind: .text))
        XCTAssertFalse(LibraryFilter.matches(item, search: "", archived: false, collection: .all, kind: .image))
        XCTAssertFalse(LibraryFilter.matches(item, search: "", archived: false, collection: .unfiled, kind: .text))
        item.isArchived = true
        XCTAssertFalse(LibraryFilter.matches(item, search: "", archived: false, collection: .all, kind: .text))
        XCTAssertTrue(LibraryFilter.matches(item, search: "", archived: true, collection: .all, kind: .text))
    }

    @MainActor
    func testMetadataPartialSuccessOfflineAndExistingTitles() async throws {
        let container = try LinkStore.container(at: root())
        let context = container.mainContext
        try LinkStore.captureLink(URL(string: "https://good.example")!, into: context)
        try LinkStore.captureLink(URL(string: "https://offline.example")!, into: context)
        try LinkStore.captureLink(URL(string: "https://named.example")!, title: "Titolo personale", into: context)
        let items = try context.fetch(FetchDescriptor<CapturedLink>())
        let loader = LinkTitleController()
        var requests = 0
        loader.start(items, in: context) { url in
            requests += 1
            if url.host == "offline.example" { throw URLError(.notConnectedToInternet) }
            return " Titolo dal sito "
        }
        try await wait(loader)
        XCTAssertEqual(requests, 2)
        XCTAssertEqual(items.first { $0.urlString.contains("good.example") }?.title, "Titolo dal sito")
        XCTAssertNil(items.first { $0.urlString.contains("offline.example") }?.title)
        XCTAssertEqual(items.first { $0.urlString.contains("named.example") }?.title, "Titolo personale")
        XCTAssertNotNil(loader.message)
    }

    @MainActor
    func testCancelledMetadataAndTitleEditedDuringFetchAreNotOverwritten() async throws {
        let container = try LinkStore.container(at: root())
        let context = container.mainContext
        try LinkStore.captureLink(URL(string: "https://example.com")!, into: context)
        let item = try XCTUnwrap(context.fetch(FetchDescriptor<CapturedLink>()).first)
        let loader = LinkTitleController()
        loader.start([item], in: context) { _ in
            try await Task.sleep(nanoseconds: 100_000_000)
            return "Da ignorare"
        }
        await Task.yield()
        loader.cancel()
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertNil(item.title)
        loader.start([item], in: context) { _ in
            try LinkStore.update(item, title: "Modifica manuale", notes: "Note", collection: nil, in: context)
            return "Titolo remoto"
        }
        try await wait(loader)
        XCTAssertEqual(item.title, "Modifica manuale")
        XCTAssertEqual(item.notes, "Note")
    }

    @MainActor
    private func wait(_ loader: LinkTitleController) async throws {
        let deadline = Date().addingTimeInterval(3)
        while loader.isLoading && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(loader.isLoading)
    }
}

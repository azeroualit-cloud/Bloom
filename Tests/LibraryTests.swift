import XCTest
import SwiftData
@testable import Bloom

final class LibraryTests: XCTestCase {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }

    @MainActor
    func testMetadataCollectionAndArchivePersistAcrossReopen() throws {
        let root = try temporaryRoot()
        do {
            let container = try LinkStore.container(at: root)
            let context = container.mainContext
            try LinkStore.capture(URL(string: "https://pin.it/example")!, into: context)
            let link = try XCTUnwrap(context.fetch(FetchDescriptor<CapturedLink>()).first)
            let collection = try LinkStore.saveCollection(nil, name: " Idee ", in: context)
            try LinkStore.update(link, title: " Una ricetta ", notes: " Per domenica ",
                                 collection: collection, in: context)
            try LinkStore.setArchived(true, for: link, in: context)
        }
        let container = try LinkStore.container(at: root)
        let link = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertEqual(link.title, "Una ricetta")
        XCTAssertEqual(link.notes, "Per domenica")
        XCTAssertEqual(link.collection?.name, "Idee")
        XCTAssertTrue(link.isArchived)
        try LinkStore.setArchived(false, for: link, in: container.mainContext)
        XCTAssertFalse(link.isArchived)
    }

    @MainActor
    func testRenameAndDeleteCollectionPreserveContent() throws {
        let container = try LinkStore.container(at: temporaryRoot())
        let context = container.mainContext
        try LinkStore.capture(URL(string: "https://example.com")!, into: context)
        let link = try XCTUnwrap(context.fetch(FetchDescriptor<CapturedLink>()).first)
        let collection = try LinkStore.saveCollection(nil, name: "Idee", in: context)
        try LinkStore.update(link, title: "Titolo", notes: "Note", collection: collection, in: context)
        try LinkStore.saveCollection(collection, name: "Progetti", in: context)
        XCTAssertEqual(link.collection?.name, "Progetti")
        try LinkStore.deleteCollection(collection, in: context)
        XCTAssertNil(link.collection)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CapturedLink>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LinkCollection>()), 0)
        XCTAssertEqual(link.notes, "Note")
    }

    @MainActor
    func testRejectsEmptyAndEquivalentCollectionNames() throws {
        let container = try LinkStore.container(at: temporaryRoot())
        let context = container.mainContext
        try LinkStore.saveCollection(nil, name: "Caffè", in: context)
        XCTAssertThrowsError(try LinkStore.saveCollection(nil, name: "  CAFFE  ", in: context))
        XCTAssertThrowsError(try LinkStore.saveCollection(nil, name: "  ", in: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LinkCollection>()), 1)
    }

    @MainActor
    func testSearchCombinesMetadataCollectionAndArchiveFilters() {
        let link = CapturedLink(url: URL(string: "https://example.com/video")!)
        link.title = "Caffè fatto bene"
        link.notes = "Ricetta da provare"
        let collection = LinkCollection(name: "Cucina")
        link.collection = collection
        for query in ["caffe", "RICETTA", "example.com", "cucina"] {
            XCTAssertTrue(LibraryFilter.matches(link, search: query, archived: false, collection: .all))
        }
        XCTAssertFalse(LibraryFilter.matches(link, search: "", archived: false, collection: .unfiled))
        XCTAssertFalse(LibraryFilter.matches(link, search: "", archived: true, collection: .all))
        XCTAssertTrue(LibraryFilter.matches(link, search: "", archived: false, collection: .collection(collection.id)))
        XCTAssertFalse(LibraryFilter.matches(link, search: "inesistente", archived: false, collection: .all))
    }

    @MainActor
    func testMigratesPreviousStoreWithoutLosingExistingLinks() throws {
        let root = try temporaryRoot()
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        do {
            let schema = Schema([PreviousLibrary.CapturedLink.self])
            let config = ModelConfiguration(schema: schema, url: root.appendingPathComponent("Bloom.store"),
                                             cloudKitDatabase: .none)
            let previous = try ModelContainer(for: schema, configurations: [config])
            let link = PreviousLibrary.CapturedLink(id: id, url: "https://example.com/old", date: date)
            previous.mainContext.insert(link)
            try previous.mainContext.save()
        }
        let current = try LinkStore.container(at: root)
        let records = try current.mainContext.fetch(FetchDescriptor<CapturedLink>())
        XCTAssertEqual(records.count, 1)
        let link = try XCTUnwrap(records.first)
        XCTAssertEqual(link.id, id)
        XCTAssertEqual(link.urlString, "https://example.com/old")
        XCTAssertEqual(link.capturedAt, date)
        XCTAssertNil(link.title)
        XCTAssertNil(link.notes)
        XCTAssertNil(link.collection)
        XCTAssertFalse(link.isArchived)
        XCTAssertEqual(link.kind, .link)
        XCTAssertNil(link.attachmentData)
        try LinkStore.update(link, title: "Vecchio link", notes: "", collection: nil, in: current.mainContext)
        XCTAssertEqual(link.title, "Vecchio link")
    }
}

// Exact persisted fields from build 3, before Library metadata was introduced.
private enum PreviousLibrary {
    @Model
    final class CapturedLink {
        var id: UUID
        var urlString: String
        var capturedAt: Date
        init(id: UUID, url: String, date: Date) {
            self.id = id
            urlString = url
            capturedAt = date
        }
    }
}

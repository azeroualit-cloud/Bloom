import XCTest
import SwiftData
@testable import Bloom

final class MediaCaptureTests: XCTestCase {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    @MainActor
    func testTextAndAttachmentPersistIndependentlyOfOriginal() throws {
        let directory = try root()
        let source = directory.appendingPathComponent("original.txt")
        let data = Data("Un contenuto personale".utf8)
        try data.write(to: source)
        let payload = try AttachmentLoader.read(source)
        do {
            let container = try LinkStore.container(at: directory)
            let context = container.mainContext
            XCTAssertTrue(try LinkStore.captureText("Testo da ritrovare", title: "Appunto", into: context))
            XCTAssertFalse(try LinkStore.captureText("Testo da ritrovare", title: "Altro titolo", into: context))
            XCTAssertTrue(try LinkStore.captureAttachment(payload, into: context))
            XCTAssertFalse(try LinkStore.captureAttachment(payload, into: context))
        }
        try FileManager.default.removeItem(at: source)
        let reopened = try LinkStore.container(at: directory)
        let records = try reopened.mainContext.fetch(FetchDescriptor<CapturedLink>())
        XCTAssertEqual(records.count, 2)
        let attachment = try XCTUnwrap(records.first { $0.kind == .file })
        XCTAssertEqual(attachment.attachmentData, data)
        XCTAssertEqual(attachment.fileName, "original.txt")
        let text = try XCTUnwrap(records.first { $0.kind == .text })
        XCTAssertEqual(text.textContent, "Testo da ritrovare")
        XCTAssertTrue(LibraryFilter.matches(text, search: "ritrovare", archived: false, collection: .all))
    }

    @MainActor
    func testEmptyTextDoesNotWrite() throws {
        let container = try LinkStore.container(at: root())
        XCTAssertThrowsError(try LinkStore.captureText(" \n ", title: "", into: container.mainContext))
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<CapturedLink>()), 0)
    }

    @MainActor
    func testEditableTextPersistsAndKeepsContentDeduplicated() throws {
        let container = try LinkStore.container(at: root())
        let context = container.mainContext
        XCTAssertTrue(try LinkStore.captureText("# Prima", title: "Nota", into: context))
        XCTAssertTrue(try LinkStore.captureText("# Seconda", title: "Altra", into: context))
        let items = try context.fetch(FetchDescriptor<CapturedLink>())
        let first = try XCTUnwrap(items.first { $0.textContent == "# Prima" })
        try LinkStore.updateTextContent("# Aggiornata\n\nContenuto", for: first, in: context)
        XCTAssertEqual(first.textContent, "# Aggiornata\n\nContenuto")
        XCTAssertThrowsError(try LinkStore.updateTextContent("# Seconda", for: first, in: context))
        XCTAssertEqual(first.textContent, "# Aggiornata\n\nContenuto")
    }

    func testOversizedFileAndDirectoryAreRejected() throws {
        let directory = try root()
        let url = directory.appendingPathComponent("large.bin")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(AttachmentLoader.maximumBytes + 1))
        try handle.close()
        XCTAssertThrowsError(try AttachmentLoader.read(url))
        XCTAssertThrowsError(try AttachmentLoader.read(directory))
    }

    func testFingerprintUsesContentRatherThanFilename() {
        let data = Data([1, 2, 3])
        let first = AttachmentPayload(data: data, name: "a.pdf", type: "com.adobe.pdf", kind: .file)
        let second = AttachmentPayload(data: data, name: "b.pdf", type: "com.adobe.pdf", kind: .file)
        XCTAssertEqual(first.fingerprint, second.fingerprint)
        XCTAssertNotEqual(first.fingerprint, ContentFingerprint.make(data, kind: .image))
    }
}

private enum PreviousMediaLibrary {
    @Model final class CapturedLink {
        var id: UUID
        var urlString: String
        var capturedAt: Date
        var title: String?
        var notes: String?
        var isArchived: Bool = false
        var collection: LinkCollection?
        init(url: String) {
            id = UUID()
            urlString = url
            capturedAt = .now
        }
    }
    @Model final class LinkCollection {
        var id: UUID
        var name: String
        var createdAt: Date
        @Relationship(deleteRule: .nullify, inverse: \CapturedLink.collection)
        var links: [CapturedLink] = []
        init(name: String) {
            id = UUID()
            self.name = name
            createdAt = .now
        }
    }
}

extension MediaCaptureTests {
    @MainActor
    func testMigratesBuildFourCollectionsAndMetadata() throws {
        let directory = try root()
        do {
            let schema = Schema([PreviousMediaLibrary.CapturedLink.self, PreviousMediaLibrary.LinkCollection.self])
            let config = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("Bloom.store"),
                                             cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let item = PreviousMediaLibrary.CapturedLink(url: "https://example.com/previous")
            let collection = PreviousMediaLibrary.LinkCollection(name: "Idee")
            container.mainContext.insert(collection)
            container.mainContext.insert(item)
            item.title = "Titolo precedente"
            item.notes = "Note precedenti"
            item.isArchived = true
            item.collection = collection
            try container.mainContext.save()
        }
        let current = try LinkStore.container(at: directory)
        let item = try XCTUnwrap(current.mainContext.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertEqual(item.title, "Titolo precedente")
        XCTAssertEqual(item.notes, "Note precedenti")
        XCTAssertTrue(item.isArchived)
        XCTAssertEqual(item.collection?.name, "Idee")
        XCTAssertEqual(item.kind, .link)
        XCTAssertNil(item.attachmentData)
        XCTAssertTrue(try LinkStore.captureText("Nuovo testo", title: "", into: current.mainContext))
        XCTAssertEqual(try current.mainContext.fetchCount(FetchDescriptor<CapturedLink>()), 2)
    }
}

extension MediaCaptureTests {
    @MainActor
    func testMarkdownCoordinatedImportPersistsAndReadsWithoutQuickLook() throws {
        let directory = try root()
        let source = directory.appendingPathComponent("nota.md")
        let body = "# Titolo\n\nUn testo con accenti: caffè.\n- elemento"
        try Data(body.utf8).write(to: source)
        let payload = try AttachmentLoader.readCoordinated(source)
        let container = try LinkStore.container(at: directory)
        try LinkStore.captureAttachment(payload, into: container.mainContext)
        try FileManager.default.removeItem(at: source)
        let item = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<CapturedLink>()).first)
        XCTAssertEqual(DocumentText.decode(try XCTUnwrap(item.attachmentData), name: item.fileName!, type: item.contentType), body)
    }

    func testTextDecoderPreservesBOMUnicodeAndRejectsBinaryAndOversizedData() {
        let body = "# Caffè ☕"
        XCTAssertEqual(DocumentText.decode(Data(("\u{FEFF}" + body).utf8), name: "nota.md", type: nil), body)
        XCTAssertEqual(DocumentText.decode(body.data(using: .utf16)!, name: "nota.markdown", type: nil), body)
        XCTAssertNil(DocumentText.decode(Data([0, 1, 2, 255]), name: "nota.md", type: nil))
        XCTAssertNil(DocumentText.decode(Data("testo".utf8), name: "file.bin", type: "public.data"))
        XCTAssertNil(DocumentText.decode(Data(repeating: 65, count: DocumentText.maximumPreviewBytes + 1), name: "nota.md", type: nil))
    }
}

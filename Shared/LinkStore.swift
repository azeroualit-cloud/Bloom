import Foundation
import SwiftData

@MainActor
enum LinkStore {
    static func container(at directory: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = Schema([CapturedLink.self, LinkCollection.self])
        let configuration = ModelConfiguration(
            schema: schema, url: directory.appendingPathComponent("Bloom.store"),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @discardableResult
    static func capture(_ url: URL, into context: ModelContext) throws -> Bool {
        try captureLink(url, into: context).inserted
    }

    static func captureLink(_ url: URL, title: String = "", collectionID: UUID? = nil,
                            into context: ModelContext) throws -> CaptureReceipt {
        let value = try LinkValidation.validate(url).absoluteString
        let request = FetchDescriptor<CapturedLink>(predicate: #Predicate { $0.urlString == value })
        if let existing = try context.fetch(request).first { return CaptureReceipt(id: existing.id, inserted: false) }
        let collection = try resolveCollection(collectionID, in: context)
        let item = CapturedLink(url: url)
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        item.collection = collection
        context.insert(item)
        try save(context)
        return CaptureReceipt(id: item.id, inserted: true)
    }

    @discardableResult
    static func captureText(_ text: String, title: String, into context: ModelContext) throws -> Bool {
        try captureTextItem(text, title: title, into: context).inserted
    }

    static func captureTextItem(_ text: String, title: String, collectionID: UUID? = nil,
                                into context: ModelContext) throws -> CaptureReceipt {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ImportError.emptyText }
        let data = Data(text.utf8)
        guard data.count <= AttachmentLoader.maximumBytes else { throw ImportError.tooLarge }
        let key = ContentFingerprint.make(data, kind: .text)
        if let existing = try fingerprintItem(key, in: context) { return CaptureReceipt(id: existing.id, inserted: false) }
        let collection = try resolveCollection(collectionID, in: context)
        let item = CapturedLink(kind: .text)
        item.textContent = text
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.title = cleanTitle.isEmpty ? String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)) : cleanTitle
        item.collection = collection
        item.contentFingerprint = key
        context.insert(item)
        try save(context)
        return CaptureReceipt(id: item.id, inserted: true)
    }

    @discardableResult
    static func captureAttachment(_ payload: AttachmentPayload, into context: ModelContext) throws -> Bool {
        try captureAttachmentItem(payload, into: context).inserted
    }

    static func captureAttachmentItem(_ payload: AttachmentPayload, collectionID: UUID? = nil,
                                      into context: ModelContext) throws -> CaptureReceipt {
        guard payload.data.count <= AttachmentLoader.maximumBytes else { throw ImportError.tooLarge }
        guard payload.kind == .image || payload.kind == .file else { throw ImportError.invalidFile }
        let key = payload.fingerprint
        if let existing = try fingerprintItem(key, in: context) { return CaptureReceipt(id: existing.id, inserted: false) }
        let collection = try resolveCollection(collectionID, in: context)
        let item = CapturedLink(kind: payload.kind)
        item.fileName = payload.name
        item.contentType = payload.type
        item.attachmentData = payload.data
        item.attachmentByteCount = payload.data.count
        item.contentFingerprint = key
        item.collection = collection
        context.insert(item)
        try save(context)
        return CaptureReceipt(id: item.id, inserted: true)
    }

    private static func fingerprintItem(_ key: String, in context: ModelContext) throws -> CapturedLink? {
        try context.fetch(FetchDescriptor<CapturedLink>(predicate: #Predicate { $0.contentFingerprint == key })).first
    }

    static func resolveCollection(_ id: UUID?, in context: ModelContext) throws -> LinkCollection? {
        guard let id else { return nil }
        guard let collection = try context.fetch(FetchDescriptor<LinkCollection>(predicate: #Predicate { $0.id == id })).first else {
            throw LibraryError.collectionMissing
        }
        return collection
    }

    enum BulkChange { case archived(Bool), collection(UUID?) }

    static func apply(_ change: BulkChange, to ids: Set<UUID>, in context: ModelContext) throws -> Int {
        let items = try context.fetch(FetchDescriptor<CapturedLink>()).filter { ids.contains($0.id) }
        guard items.count == ids.count else { throw LibraryError.selectionMissing }
        var collection: LinkCollection?
        if case .collection(let id) = change { collection = try resolveCollection(id, in: context) }
        for item in items {
            switch change {
            case .archived(let value): item.isArchived = value
            case .collection: item.collection = collection
            }
        }
        try save(context)
        return items.count
    }

    @discardableResult
    static func fillMissingTitle(_ title: String, for item: CapturedLink, in context: ModelContext) throws -> Bool {
        let clean = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard item.kind == .link, item.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
              !clean.isEmpty else { return false }
        item.title = clean
        try save(context)
        return true
    }

    static func update(_ link: CapturedLink, title: String, notes: String,
                       collection: LinkCollection?, in context: ModelContext) throws {
        link.title = title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        link.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        link.collection = collection
        try save(context)
    }

    static func updateTextContent(_ text: String, for link: CapturedLink, in context: ModelContext) throws {
        guard link.kind == .text else { throw ImportError.emptyText }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ImportError.emptyText }
        let data = Data(text.utf8)
        guard data.count <= AttachmentLoader.maximumBytes else { throw ImportError.tooLarge }
        let key = ContentFingerprint.make(data, kind: .text)
        if let existing = try fingerprintItem(key, in: context), existing.id != link.id { throw LibraryError.duplicateContent }
        link.textContent = text
        link.contentFingerprint = key
        try save(context)
    }

    static func updateDocumentText(_ text: String, for link: CapturedLink, in context: ModelContext) throws {
        guard link.kind == .file else { throw ImportError.invalidFile }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ImportError.emptyText }
        let data = Data(text.utf8)
        guard data.count <= AttachmentLoader.maximumBytes else { throw ImportError.tooLarge }
        let key = ContentFingerprint.make(data, kind: .file)
        if let existing = try fingerprintItem(key, in: context), existing.id != link.id { throw LibraryError.duplicateContent }
        link.attachmentData = data
        link.attachmentByteCount = data.count
        link.contentFingerprint = key
        try save(context)
    }

    static func storePreview(_ data: Data?, sourceURL: URL?, for link: CapturedLink, in context: ModelContext) throws {
        guard link.kind == .link else { return }
        link.previewImageData = data
        link.previewSourceURL = sourceURL?.absoluteString
        try save(context)
    }

    static func setArchived(_ archived: Bool, for link: CapturedLink, in context: ModelContext) throws {
        link.isArchived = archived
        try save(context)
    }

    @discardableResult
    static func saveCollection(_ collection: LinkCollection?, name: String,
                               in context: ModelContext) throws -> LinkCollection {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw LibraryError.emptyCollectionName }
        let key = clean.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let existing = try context.fetch(FetchDescriptor<LinkCollection>())
        guard !existing.contains(where: {
            $0.id != collection?.id &&
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == key
        }) else { throw LibraryError.duplicateCollection }
        let result: LinkCollection
        if let collection { collection.name = clean; result = collection }
        else { result = LinkCollection(name: clean); context.insert(result) }
        try save(context)
        return result
    }

    static func deleteCollection(_ collection: LinkCollection, in context: ModelContext) throws {
        // Explicitly detach links before deletion; never cascade into personal content.
        for link in collection.links { link.collection = nil }
        context.delete(collection)
        try save(context)
    }

    private static func save(_ context: ModelContext) throws {
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

}

@MainActor
enum LocalLibrary {
    private static var cached: ModelContainer?

    static func open() throws -> ModelContainer {
        if let cached { return cached }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-in-memory") {
            let schema = Schema([CapturedLink.self, LinkCollection.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            cached = container
            return container
        }
        #endif
        let root = try FileManager.default.url(for: .applicationSupportDirectory,
                                              in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Bloom", isDirectory: true)
        let container = try LinkStore.container(at: root)
        cached = container
        return container
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct CaptureReceipt {
    let id: UUID
    let inserted: Bool
}

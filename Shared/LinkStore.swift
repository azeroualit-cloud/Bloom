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

    /// Returns false for an exact URL already present. All entry points use this path.
    @discardableResult
    static func capture(_ url: URL, into context: ModelContext) throws -> Bool {
        let valid = try LinkValidation.validate(url)
        let value = valid.absoluteString
        let request = FetchDescriptor<CapturedLink>(predicate: #Predicate { $0.urlString == value })
        guard try context.fetch(request).isEmpty else { return false }
        context.insert(CapturedLink(url: valid))
        do { try context.save() }
        catch { context.rollback(); throw error }
        return true
    }

    @discardableResult
    static func captureText(_ text: String, title: String, into context: ModelContext) throws -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ImportError.emptyText }
        let data = Data(text.utf8)
        guard data.count <= AttachmentLoader.maximumBytes else { throw ImportError.tooLarge }
        let key = ContentFingerprint.make(data, kind: .text)
        if try containsFingerprint(key, in: context) { return false }
        let item = CapturedLink(kind: .text)
        item.textContent = text
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.title = cleanTitle.isEmpty ? String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)) : cleanTitle
        item.contentFingerprint = key
        context.insert(item)
        try save(context)
        return true
    }

    @discardableResult
    static func captureAttachment(_ payload: AttachmentPayload, into context: ModelContext) throws -> Bool {
        guard payload.data.count <= AttachmentLoader.maximumBytes else { throw ImportError.tooLarge }
        guard payload.kind == .image || payload.kind == .file else { throw ImportError.invalidFile }
        let key = payload.fingerprint
        if try containsFingerprint(key, in: context) { return false }
        let item = CapturedLink(kind: payload.kind)
        item.fileName = payload.name
        item.contentType = payload.type
        item.attachmentData = payload.data
        item.attachmentByteCount = payload.data.count
        item.contentFingerprint = key
        context.insert(item)
        try save(context)
        return true
    }

    private static func containsFingerprint(_ key: String, in context: ModelContext) throws -> Bool {
        let request = FetchDescriptor<CapturedLink>(predicate: #Predicate { $0.contentFingerprint == key })
        return try !context.fetch(request).isEmpty
    }

    static func update(_ link: CapturedLink, title: String, notes: String,
                       collection: LinkCollection?, in context: ModelContext) throws {
        link.title = title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        link.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        link.collection = collection
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

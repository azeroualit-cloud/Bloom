import Foundation
import SwiftData
import UniformTypeIdentifiers

@MainActor
enum LinkStore {
    static func deleteNote(_ item: CapturedLink, in context: ModelContext) throws {
        context.delete(item)
        try save(context)
    }
    static func setImageFraming(_ value: ImageFraming, for item: CapturedLink, in context: ModelContext) throws {
        guard value.isValid else { throw ImportError.invalidFile }
        item.imageFramingData = try JSONEncoder().encode(value)
        try save(context)
    }
    static func updateNoteFile(_ file: NoteFile, for item: CapturedLink, in context: ModelContext) throws {
        var files = item.noteFiles
        guard let index = files.firstIndex(where: { $0.id == file.id }), file.framing?.isValid != false else { throw ImportError.invalidFile }
        files[index] = file
        let primary = item.attachmentData?.count ?? 0
        guard item.noteBody.utf8.count + primary + files.reduce(0, { $0 + $1.data.count }) <= AttachmentLoader.maximumBytes else { throw ImportError.tooLarge }
        item.noteFilesData = try JSONEncoder().encode(files)
        item.noteFileCount = files.count
        try save(context)
    }
    static func initializeTags(in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<LinkCollection>())
        for name in NoteTags.initial where !existing.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            context.insert(LinkCollection(name: name))
        }
        for item in try context.fetch(FetchDescriptor<CapturedLink>()) where item.tagIDsJSON == nil {
            item.tagIDs = item.tagIDs
        }
        try save(context)
    }

    static func saveNote(existing: CapturedLink? = nil, title: String, body: String, urls: [URL],
                         files: [NoteFile], tags: Set<UUID>, in context: ModelContext) throws -> CaptureReceipt {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanTitle.utf8.count <= 1_024 * 1_024 else { throw ImportError.tooLarge }
        guard !cleanTitle.isEmpty || !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !urls.isEmpty || !files.isEmpty || existing?.kind == .image || existing?.kind == .file else { throw NoteError.empty }
        let primaryBytes = (existing?.kind == .image || existing?.kind == .file) ? (existing?.attachmentData?.count ?? 0) : 0
        let primaryCount = (existing?.kind == .image || existing?.kind == .file) ? 1 : 0
        guard urls.count + files.count + primaryCount <= 10 else { throw NoteError.tooManyAttachments }
        guard body.utf8.count + primaryBytes + files.reduce(0, { $0 + $1.data.count }) <= AttachmentLoader.maximumBytes else { throw ImportError.tooLarge }
        var seenURLs = Set<String>()
        let validated = try urls.map { try LinkValidation.validate($0) }.filter { seenURLs.insert($0.absoluteString).inserted }
        for tag in tags { _ = try resolveCollection(tag, in: context) }
        let linksJSON = validated.isEmpty ? nil : String(data: try JSONEncoder().encode(validated.map(\.absoluteString)), encoding: .utf8)
        let promoteFile = existing == nil && validated.isEmpty && !files.isEmpty
        let storedFiles = promoteFile ? Array(files.dropFirst()) : files
        let filesData = storedFiles.isEmpty ? nil : try JSONEncoder().encode(storedFiles)
        if existing == nil, validated.count == 1, files.isEmpty, body.isEmpty, cleanTitle.isEmpty {
            let value = validated[0].absoluteString
            if let duplicate = try context.fetch(FetchDescriptor<CapturedLink>(predicate: #Predicate { $0.urlString == value })).first {
                return CaptureReceipt(id: duplicate.id, inserted: false)
            }
        }
        let item = existing ?? CapturedLink(kind: validated.isEmpty ? .text : .link)
        if existing == nil { context.insert(item) }
        if promoteFile, let file = files.first {
            item.contentKind = (UTType(file.type)?.conforms(to: .image) == true ? ContentKind.image : .file).rawValue
            item.fileName = file.name; item.contentType = file.type; item.attachmentData = file.data
            item.attachmentByteCount = file.data.count
        }
        let previousURL = item.allLinks.first
        if item.kind == .link && validated.isEmpty {
            item.contentKind = ContentKind.text.rawValue
            item.urlString = ""
        }
        item.title = cleanTitle.nilIfEmpty
        // Existing primary files/images retain their original bytes and kind.
        if item.kind == .link {
            item.urlString = validated.first?.absoluteString ?? item.urlString
            item.noteLinksJSON = String(data: try JSONEncoder().encode(validated.dropFirst().map(\.absoluteString)), encoding: .utf8)
            item.notes = body.nilIfEmpty
        } else {
            item.noteLinksJSON = linksJSON
            if item.kind == .text { item.textContent = body; item.contentFingerprint = nil }
            else { item.notes = body.nilIfEmpty }
        }
        item.noteFilesData = filesData
        item.noteFileCount = storedFiles.count
        item.noteVersion = 1
        item.tagIDs = tags
        if previousURL != item.allLinks.first {
            item.previewImageData = nil; item.previewSourceURL = nil; item.previewAttemptedAt = nil
        }
        try save(context)
        return CaptureReceipt(id: item.id, inserted: existing == nil)
    }

    enum TagChange: String, CaseIterable, Identifiable {
        case add, remove, replace
        var id: String { rawValue }
        var label: String {
            switch self { case .add: return "Aggiungi"; case .remove: return "Rimuovi"; case .replace: return "Sostituisci" }
        }
    }
    static func setTags(_ tags: Set<UUID>, for items: [CapturedLink], mode: TagChange = .replace, in context: ModelContext) throws {
        for id in tags { _ = try resolveCollection(id, in: context) }
        for item in items {
            switch mode {
            case .add: item.tagIDs = item.tagIDs.union(tags)
            case .remove: item.tagIDs = item.tagIDs.subtracting(tags)
            case .replace: item.tagIDs = tags
            }
        }
        try save(context)
    }
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
                if item.tagIDsJSON != nil { item.tagIDs = Set(collection.map { [$0.id] } ?? []) }
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
        if link.tagIDsJSON != nil { link.tagIDs = Set(collection.map { [$0.id] } ?? []) }
        try save(context)
    }

    static func updateTextContent(_ text: String, for link: CapturedLink, in context: ModelContext) throws {
        guard link.kind == .text else { throw ImportError.emptyText }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ImportError.emptyText }
        let data = Data(text.utf8)
        guard data.count + link.noteFiles.reduce(0, { $0 + $1.data.count }) <= AttachmentLoader.maximumBytes else { throw ImportError.tooLarge }
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
        guard data.count + link.noteBody.utf8.count + link.noteFiles.reduce(0, { $0 + $1.data.count }) <= AttachmentLoader.maximumBytes else { throw ImportError.tooLarge }
        let key = ContentFingerprint.make(data, kind: .file)
        if let existing = try fingerprintItem(key, in: context), existing.id != link.id { throw LibraryError.duplicateContent }
        link.attachmentData = data
        link.attachmentByteCount = data.count
        link.contentFingerprint = key
        try save(context)
    }

    static func storePreview(_ data: Data?, sourceURL: URL?, for link: CapturedLink, in context: ModelContext) throws {
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
        for item in try context.fetch(FetchDescriptor<CapturedLink>()) where item.tagIDs.contains(collection.id) {
            var tags = item.tagIDs
            tags.remove(collection.id)
            item.tagIDs = tags
        }
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
            try LinkStore.initializeTags(in: container.mainContext)
            if ProcessInfo.processInfo.arguments.contains("--ui-test-attachments") {
                let note = CapturedLink(kind: .text)
                note.title = "Attachment fixture"; note.textContent = "Documents"; note.noteVersion = 1
                let file = NoteFile(name: "secondary.md", type: "public.text", data: Data("# Original".utf8))
                note.noteFilesData = try JSONEncoder().encode([file]); note.noteFileCount = 1
                container.mainContext.insert(note)
                try container.mainContext.save()
            }
            if ProcessInfo.processInfo.arguments.contains("--ui-test-browser") {
                let note = CapturedLink(kind: .link)
                note.urlString = "https://example.invalid/saved"; note.title = "Browser fixture"; note.noteVersion = 1
                note.previewAttemptedAt = .now
                container.mainContext.insert(note)
                try container.mainContext.save()
            }
            cached = container
            return container
        }
        #endif
        let root = try FileManager.default.url(for: .applicationSupportDirectory,
                                              in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Bloom", isDirectory: true)
        let container = try LinkStore.container(at: root)
        if !UserDefaults.standard.bool(forKey: "notes.tags.initialized") {
            try LinkStore.initializeTags(in: container.mainContext)
            UserDefaults.standard.set(true, forKey: "notes.tags.initialized")
        }
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

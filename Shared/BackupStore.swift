import Foundation
import SwiftData

struct BackupImportResult {
    var added = 0
    var skipped = 0
    var collectionsAdded = 0
}

@MainActor
enum BackupStore {
    static func snapshot(from container: ModelContainer) throws -> LibraryBackup {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let collections = try context.fetch(FetchDescriptor<LinkCollection>())
        let items = try context.fetch(FetchDescriptor<CapturedLink>())
        guard items.count <= LibraryBackup.maximumItems,
              collections.count <= LibraryBackup.maximumCollections else { throw BackupError.tooLarge }
        var records: [LibraryBackup.Item] = []
        var bytes = 0
        for item in items {
            let data = item.attachmentData
            bytes += (data?.count ?? 0) + (item.textContent?.utf8.count ?? 0)
            guard bytes <= LibraryBackup.maximumPayloadBytes else { throw BackupError.tooLarge }
            records.append(LibraryBackup.Item(id: item.id, kind: item.kind.rawValue, capturedAt: item.capturedAt,
                urlString: item.urlString, title: item.title, notes: item.notes, archived: item.isArchived,
                collectionID: item.collection?.id, text: item.textContent, fileName: item.fileName,
                contentType: item.contentType, data: data, tagIDs: Array(item.tagIDs),
                noteLinks: item.noteLinks.map(\.absoluteString), noteFiles: item.noteFiles, imageFraming: item.imageFraming, noteVersion: item.noteVersion))
        }
        return LibraryBackup(collections: collections.map {
            .init(id: $0.id, name: $0.name, createdAt: $0.createdAt)
        }, items: records)
    }

    static func restore(_ backup: LibraryBackup, into container: ModelContainer) throws -> BackupImportResult {
        _ = try backup.validated()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        var result = BackupImportResult()
        do {
            let existingCollections = try context.fetch(FetchDescriptor<LinkCollection>())
            var byID = Dictionary(existingCollections.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            var byName = Dictionary(existingCollections.map { (normalized($0.name), $0) }, uniquingKeysWith: { first, _ in first })
            var mapping: [UUID: LinkCollection] = [:]
            for record in backup.collections {
                let key = normalized(record.name)
                if let collection = byID[record.id] ?? byName[key] { mapping[record.id] = collection }
                else {
                    let collection = LinkCollection(name: record.name.trimmingCharacters(in: .whitespacesAndNewlines))
                    collection.id = record.id
                    collection.createdAt = record.createdAt
                    context.insert(collection)
                    mapping[record.id] = collection
                    byID[record.id] = collection
                    byName[key] = collection
                    result.collectionsAdded += 1
                }
            }
            let existing = try context.fetch(FetchDescriptor<CapturedLink>())
            var ids = Set(existing.map(\.id))
            var urls = Set(existing.filter { $0.kind == .link }.map(\.urlString))
            var fingerprints = Set(existing.compactMap(\.contentFingerprint))
            for record in backup.items {
                let fingerprint = record.fingerprint
                if ids.contains(record.id) || (record.noteVersion == nil && record.kind == ContentKind.link.rawValue && urls.contains(record.urlString))
                    || fingerprint.map({ fingerprints.contains($0) }) == true {
                    result.skipped += 1
                    continue
                }
                guard let kind = ContentKind(rawValue: record.kind) else { throw BackupError.invalid }
                let item = CapturedLink(kind: kind)
                item.id = record.id
                item.capturedAt = record.capturedAt
                item.urlString = record.urlString
                item.title = record.title
                item.notes = record.notes
                item.isArchived = record.archived
                item.collection = record.collectionID.flatMap { mapping[$0] }
                item.textContent = record.text
                item.fileName = record.fileName
                item.contentType = record.contentType
                item.attachmentData = record.data
                item.attachmentByteCount = record.data?.count
                item.contentFingerprint = fingerprint
                if let tags = record.tagIDs { item.tagIDs = Set(tags.compactMap { mapping[$0]?.id }) }
                item.noteLinksJSON = record.noteLinks.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
                item.noteFilesData = record.noteFiles.flatMap { try? JSONEncoder().encode($0) }
                item.noteFileCount = record.noteFiles?.count ?? 0
                item.imageFramingData = record.imageFraming.flatMap { try? JSONEncoder().encode($0) }
                item.noteVersion = record.noteVersion
                context.insert(item)
                ids.insert(item.id)
                if kind == .link { urls.insert(record.urlString) }
                if let fingerprint { fingerprints.insert(fingerprint) }
                result.added += 1
            }
            try context.save()
            return result
        } catch { context.rollback(); throw error }
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

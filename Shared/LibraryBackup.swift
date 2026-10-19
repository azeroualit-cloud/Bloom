import Foundation

struct LibraryBackup: Codable, Sendable {
    static let maximumFileBytes = 100 * 1024 * 1024
    static let maximumPayloadBytes = 60 * 1024 * 1024
    static let maximumItems = 10_000
    static let maximumCollections = 2_000

    var format = "Bloom"
    var version = 2
    var createdAt = Date()
    var collections: [CollectionRecord]
    var items: [Item]

    struct CollectionRecord: Codable, Sendable {
        let id: UUID
        let name: String
        let createdAt: Date
    }

    struct Item: Codable, Sendable {
        let id: UUID
        let kind: String
        let capturedAt: Date
        let urlString: String
        let title: String?
        let notes: String?
        let archived: Bool
        let collectionID: UUID?
        let text: String?
        let fileName: String?
        let contentType: String?
        let data: Data?
        var tagIDs: [UUID]? = nil
        var noteLinks: [String]? = nil
        var noteFiles: [NoteFile]? = nil
        var imageFraming: ImageFraming? = nil
        var noteVersion: Int? = nil

        var fingerprint: String? {
            guard noteVersion == nil else { return nil }
            guard let type = ContentKind(rawValue: kind) else { return nil }
            if type == .text, let text, !text.isEmpty,
               (noteLinks ?? []).isEmpty, (noteFiles ?? []).isEmpty { return ContentFingerprint.make(Data(text.utf8), kind: .text) }
            if (type == .file || type == .image), let data { return ContentFingerprint.make(data, kind: type) }
            return nil
        }
    }

    func validated() throws -> LibraryBackup {
        guard format == "Bloom" else { throw BackupError.invalid }
        guard version == 1 || version == 2 else { throw BackupError.unsupportedVersion }
        guard items.count <= Self.maximumItems, collections.count <= Self.maximumCollections else {
            throw BackupError.tooLarge
        }
        let ids = Set(collections.map(\.id))
        guard ids.count == collections.count, Set(items.map(\.id)).count == items.count,
              createdAt.timeIntervalSince1970.isFinite else { throw BackupError.invalid }
        var total = 0
        func count(_ bytes: Int) throws {
            total += bytes
            guard total <= Self.maximumPayloadBytes else { throw BackupError.tooLarge }
        }
        for collection in collections {
            guard !collection.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  collection.name.utf8.count <= 1_024,
                  collection.createdAt.timeIntervalSince1970.isFinite else { throw BackupError.invalid }
            try count(collection.name.utf8.count)
        }
        for item in items {
            guard let kind = ContentKind(rawValue: item.kind),
                  item.capturedAt.timeIntervalSince1970.isFinite,
                  item.collectionID.map({ ids.contains($0) }) ?? true else { throw BackupError.invalid }
            guard (item.tagIDs ?? []).allSatisfy({ ids.contains($0) }),
                  (item.noteLinks?.count ?? 0) + (item.noteFiles?.count ?? 0) <= 10 else { throw BackupError.invalid }
            guard item.imageFraming?.isValid ?? true else { throw BackupError.invalid }
            guard item.noteVersion == nil || item.noteVersion == 1 else { throw BackupError.unsupportedVersion }
            guard (item.data?.count ?? 0) + (item.text?.utf8.count ?? 0) + (item.noteFiles ?? []).reduce(0, { $0 + $1.data.count }) <= AttachmentLoader.maximumBytes else { throw BackupError.tooLarge }
            for raw in item.noteLinks ?? [] {
                guard let url = URL(string: raw), (try? LinkValidation.validate(url)) != nil else { throw BackupError.invalid }
                try count(raw.utf8.count)
            }
            for file in item.noteFiles ?? [] {
                guard !file.name.isEmpty, file.name.utf8.count <= 1_024, file.type.utf8.count <= 1_024,
                      file.data.count <= AttachmentLoader.maximumBytes else { throw BackupError.invalid }
                try count(file.name.utf8.count + file.type.utf8.count)
                try count(file.data.count)
            }
            for value in [item.urlString, item.title, item.notes, item.fileName, item.contentType].compactMap({ $0 }) {
                guard value.utf8.count <= 1_024 * 1_024 else { throw BackupError.tooLarge }
                try count(value.utf8.count)
            }
            switch kind {
            case .link:
                guard let url = URL(string: item.urlString), (try? LinkValidation.validate(url)) != nil,
                      item.text == nil, item.data == nil else { throw BackupError.invalid }
            case .text:
                guard let text = item.text, (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    (version == 2 && (!(item.title ?? "").isEmpty || !(item.noteLinks ?? []).isEmpty || !(item.noteFiles ?? []).isEmpty))),
                      item.data == nil, item.urlString.isEmpty else { throw BackupError.invalid }
                guard text.utf8.count <= AttachmentLoader.maximumBytes else { throw BackupError.tooLarge }
                try count(text.utf8.count)
            case .image, .file:
                guard let data = item.data, let name = item.fileName, !name.isEmpty,
                      item.text == nil, item.urlString.isEmpty else { throw BackupError.invalid }
                guard data.count <= AttachmentLoader.maximumBytes else { throw BackupError.tooLarge }
                try count(data.count)
            }
        }
        return self
    }

    func encoded() throws -> Data {
        _ = try validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumFileBytes else { throw BackupError.tooLarge }
        return data
    }

    static func decode(_ data: Data) throws -> LibraryBackup {
        guard data.count <= maximumFileBytes else { throw BackupError.tooLarge }
        let decoder = JSONDecoder()
        do { return try decoder.decode(Self.self, from: data).validated() }
        catch let error as BackupError { throw error }
        catch { throw BackupError.invalid }
    }

    static func read(_ url: URL) throws -> LibraryBackup {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        var result: Result<LibraryBackup, Error>?
        var error: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: .withoutChanges, error: &error) { url in
            result = Result {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true else { throw BackupError.invalid }
                guard (values.fileSize ?? 0) <= maximumFileBytes else { throw BackupError.tooLarge }
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                var data = Data()
                while data.count <= maximumFileBytes {
                    try Task.checkCancellation()
                    let chunk = try handle.read(upToCount: min(64 * 1024, maximumFileBytes + 1 - data.count)) ?? Data()
                    if chunk.isEmpty { break }
                    data.append(chunk)
                }
                return try decode(data)
            }
        }
        if let result { return try result.get() }
        if let error { throw error }
        throw BackupError.invalid
    }
}

enum BackupError: LocalizedError {
    case invalid, unsupportedVersion, tooLarge
    var errorDescription: String? {
        switch self {
        case .invalid: return "Il file non è un backup Bloom valido o contiene dati incompleti. Nessun dato è stato importato."
        case .unsupportedVersion: return "Questa versione del backup non è supportata. Aggiorna Bloom prima di importarla."
        case .tooLarge: return "Limiti backup superati: file 100 MB, contenuti 60 MB, 10.000 elementi e 2.000 raccolte. Nessun backup parziale è stato creato o importato."
        }
    }
}

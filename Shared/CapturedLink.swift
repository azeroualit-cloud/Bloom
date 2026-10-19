import Foundation
import SwiftData

@Model
final class CapturedLink {
    var id: UUID
    var urlString: String
    var capturedAt: Date
    var title: String?
    var notes: String?
    var isArchived: Bool = false
    var collection: LinkCollection?
    var contentKind: String?
    var textContent: String?
    var fileName: String?
    var contentType: String?
    var attachmentByteCount: Int?
    var contentFingerprint: String?
    @Attribute(.externalStorage) var attachmentData: Data?
    @Attribute(.externalStorage) var previewImageData: Data?
    var previewSourceURL: String?
    var tagIDsJSON: String?
    var noteLinksJSON: String?
    @Attribute(.externalStorage) var noteFilesData: Data?
    var noteFileCount: Int?
    var previewAttemptedAt: Date?
    var imageFramingData: Data?
    var noteVersion: Int?
    var imageFraming: ImageFraming {
        guard let data = imageFramingData, let value = try? JSONDecoder().decode(ImageFraming.self, from: data), value.isValid else { return ImageFraming() }
        return value
    }

    var tagIDs: Set<UUID> {
        get {
            if let raw = tagIDsJSON, let data = raw.data(using: .utf8),
               let ids = try? JSONDecoder().decode([UUID].self, from: data) { return Set(ids) }
            return Set(collection.map { [$0.id] } ?? [])
        }
        set { tagIDsJSON = String(data: (try? JSONEncoder().encode(newValue.sorted { $0.uuidString < $1.uuidString })) ?? Data("[]".utf8), encoding: .utf8) }
    }
    var noteLinks: [URL] {
        guard let raw = noteLinksJSON, let data = raw.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return strings.compactMap(URL.init(string:)).filter { (try? LinkValidation.validate($0)) != nil }
    }
    var noteFiles: [NoteFile] {
        guard let data = noteFilesData else { return [] }
        return (try? JSONDecoder().decode([NoteFile].self, from: data)) ?? []
    }
    var allLinks: [URL] {
        let first = kind == .link ? URL(string: urlString).map { [$0] } ?? [] : []
        return first + noteLinks
    }
    var noteBody: String { kind == .text ? textContent ?? "" : notes ?? "" }

    var kind: ContentKind { ContentKind(rawValue: contentKind ?? "") ?? .link }
    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        if let line = noteBody.split(whereSeparator: { $0.isNewline }).first {
            let plain = line.trimmingCharacters(in: CharacterSet(charactersIn: "# *>-\t "))
            if !plain.isEmpty { return String(plain.prefix(80)) }
        }
        return (kind == .link ? URL(string: urlString)?.host : nil) ?? fileName ?? kind.label
    }

    init(url: URL, id: UUID = UUID(), capturedAt: Date = .now) {
        self.id = id
        self.urlString = url.absoluteString
        self.capturedAt = capturedAt
        self.title = nil
        self.notes = nil
        self.collection = nil
    }

    init(kind: ContentKind) {
        id = UUID()
        urlString = ""
        capturedAt = .now
        contentKind = kind.rawValue
    }

}

enum CaptureError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Condividi un indirizzo web HTTP o HTTPS valido."
        }
    }
}

enum LinkValidation {
    static func validate(_ url: URL) throws -> URL {
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else {
            throw CaptureError.invalidURL
        }
        return url
    }
}

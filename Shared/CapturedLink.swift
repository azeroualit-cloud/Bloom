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

    var kind: ContentKind { ContentKind(rawValue: contentKind ?? "") ?? .link }
    var displayTitle: String {
        title ?? (kind == .link ? URL(string: urlString)?.host : nil) ?? fileName ?? kind.label
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

import Foundation
import SwiftData

@Model
final class CapturedLink {
    var id: UUID
    var urlString: String
    var capturedAt: Date

    init(url: URL, id: UUID = UUID(), capturedAt: Date = .now) {
        self.id = id
        self.urlString = url.absoluteString
        self.capturedAt = capturedAt
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

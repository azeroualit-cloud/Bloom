import Foundation

enum NoteTags {
    static let initial = ["Salute", "Alimentazione", "Studio", "Lavoro", "Progetti", "Casa", "Tecnologia", "Comunicazione", "Dating", "Psicologia", "Viaggi"]
    static func validate(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 40,
              !value.contains(where: { $0.isWhitespace }), value.lowercased() != "da specificare" else {
            throw NoteError.invalidTag
        }
        return value
    }
}

enum NoteError: LocalizedError {
    case invalidTag, empty, tooManyAttachments
    var errorDescription: String? {
        switch self {
        case .invalidTag: return "Usa una sola parola per il tag (massimo 40 caratteri)."
        case .empty: return "Aggiungi un titolo, un testo o un allegato."
        case .tooManyAttachments: return "Puoi aggiungere fino a 10 allegati per nota (25 MB complessivi)."
        }
    }
}

struct NoteFile: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    let name: String
    let type: String
    let data: Data
}

struct ImageFraming: Codable, Equatable, Sendable {
    var top = 0.0
    var bottom = 0.0
    var left = 0.0
    var right = 0.0
    var isValid: Bool {
        [top, bottom, left, right].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 0.8 } &&
            top + bottom <= 0.9 && left + right <= 0.9
    }
}

enum SocialLink {
    static func isVideo(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        if host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com") { return true }
        if host == "tiktok.com" || host.hasSuffix(".tiktok.com") { return true }
        return (host == "instagram.com" || host.hasSuffix(".instagram.com")) &&
            (url.path.hasPrefix("/reel/") || url.path.hasPrefix("/reels/") || url.path.hasPrefix("/tv/"))
    }
}

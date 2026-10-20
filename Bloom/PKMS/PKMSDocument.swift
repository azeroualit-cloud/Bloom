import Foundation

struct DropboxEntry: Codable, Identifiable, Hashable {
    let tag: String
    let name: String
    let id: String?
    let pathLower: String
    let pathDisplay: String?
    let rev: String?
    let size: Int?
    enum CodingKeys: String, CodingKey {
        case tag = ".tag", name, id, rev, size
        case pathLower = "path_lower", pathDisplay = "path_display"
    }
    var isFolder: Bool { tag == "folder" }
    var isMarkdown: Bool { tag == "file" && ["md", "markdown"].contains((name as NSString).pathExtension.lowercased()) }
    var identity: String { id ?? pathLower }
    var title: String { isFolder ? name : (name as NSString).deletingPathExtension }
    var parent: String { (pathLower as NSString).deletingLastPathComponent == "/" ? "" : (pathLower as NSString).deletingLastPathComponent }
}

struct PKMSDocument: Codable, Equatable {
    let id: String
    var path: String
    var text: String
    var revision: String
    var syncedText: String
    var conflictText: String?
    var conflictRevision: String?
    var remoteDeleted = false
    var modifiedAt = Date()
    var dirty: Bool { text != syncedText }
    var hasConflict: Bool { conflictRevision != nil || remoteDeleted }

    mutating func receive(text remote: String, revision rev: String) {
        remoteDeleted = false
        if dirty && remote != syncedText && remote != text {
            conflictText = remote; conflictRevision = rev
        } else {
            if !dirty || remote == text { text = remote }
            syncedText = remote; revision = rev
            conflictText = nil; conflictRevision = nil
        }
    }
    /// A successful upload may acknowledge an older draft while typing continues.
    mutating func acknowledge(uploaded: String, revision rev: String) {
        syncedText = uploaded; revision = rev
        conflictText = nil; conflictRevision = nil
    }
}

struct PKMSIndex: Codable {
    var root: String?
    var entries: [DropboxEntry] = []
    var cursor: String?
    var lastSync: Date?
    var accountID: String?
}

enum DropboxFailure: LocalizedError, Equatable {
    case notConnected, unauthorized, conflict, cursorReset, remoteMissing, invalidResponse, unsupportedText, tooLarge, provider(Int), storage(String)
    var errorDescription: String? {
        switch self {
        case .notConnected: return "Collega Dropbox per sincronizzare il PKMS."
        case .unauthorized: return "L’accesso Dropbox è scaduto o revocato. Ricollega lo stesso account: le modifiche locali sono conservate."
        case .conflict: return "La nota è stata modificata anche su Dropbox. Le due versioni sono conservate."
        case .cursorReset: return "Dropbox richiede un aggiornamento completo dell’indice. Riprova."
        case .remoteMissing: return "Il documento non è più disponibile su Dropbox. La copia locale è conservata."
        case .invalidResponse: return "Risposta Dropbox non valida. Riprova."
        case .unsupportedText: return "Questo documento non è testo UTF-8 valido. Il file originale non è stato modificato."
        case .tooLarge: return "Questa nota supera il limite di 8 MB per l’editor. Il file originale non è stato modificato."
        case .provider(let code): return "Dropbox non disponibile (\(code)). Riprova più tardi."
        case .storage(let message): return "Salvataggio locale non riuscito: \(message)"
        }
    }
}

protocol DropboxServing: Sendable {
    func list(path: String, recursive: Bool, cursor: String?) async throws -> DropboxListing
    func download(id: String) async throws -> DropboxDownload
    func upload(path: String, revision: String, text: String) async throws -> DropboxEntry
}
struct DropboxListing: Decodable {
    let entries: [DropboxEntry]
    let cursor: String
    let hasMore: Bool
    enum CodingKeys: String, CodingKey { case entries, cursor; case hasMore = "has_more" }
}
struct DropboxDownload { let text: String; let metadata: DropboxEntry }

import Foundation
import SwiftData

@Model
final class LinkCollection {
    var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \CapturedLink.collection)
    var links: [CapturedLink] = []

    init(name: String) {
        id = UUID()
        self.name = name
        createdAt = .now
    }
}

enum LibraryError: LocalizedError {
    case emptyCollectionName
    case duplicateCollection
    case collectionMissing
    case selectionMissing

    var errorDescription: String? {
        switch self {
        case .emptyCollectionName: return "Inserisci un nome per la raccolta."
        case .duplicateCollection: return "Esiste già una raccolta con questo nome."
        case .selectionMissing: return "La selezione è cambiata. Seleziona nuovamente i contenuti."
        case .collectionMissing: return "La raccolta selezionata non è più disponibile. Scegline un’altra."
        }
    }
}

enum CollectionFilter: Hashable {
    case all
    case unfiled
    case collection(UUID)
}

enum LibraryFilter {
    static func matches(_ link: CapturedLink, search: String,
                        archived: Bool, collection: CollectionFilter, kind: ContentKind? = nil) -> Bool {
        if let kind, link.kind != kind { return false }
        guard link.isArchived == archived else { return false }
        switch collection {
        case .all: break
        case .unfiled: guard link.collection == nil else { return false }
        case .collection(let id): guard link.collection?.id == id else { return false }
        }
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        return [link.title, link.urlString, link.notes, link.collection?.name, link.textContent, link.fileName]
            .compactMap { $0 }.contains { $0.localizedStandardContains(term) }
    }
}

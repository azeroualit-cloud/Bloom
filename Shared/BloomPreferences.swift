import Foundation

enum LibrarySort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case title

    var id: String { rawValue }
    var label: String {
        switch self {
        case .newest: return "Più recenti"
        case .oldest: return "Meno recenti"
        case .title: return "Titolo"
        }
    }

    func sort(_ items: [CapturedLink]) -> [CapturedLink] {
        switch self {
        case .newest: return items.sorted { $0.capturedAt > $1.capturedAt }
        case .oldest: return items.sorted { $0.capturedAt < $1.capturedAt }
        case .title:
            return items.sorted {
                let result = $0.displayTitle.localizedStandardCompare($1.displayTitle)
                return result == .orderedSame ? $0.capturedAt > $1.capturedAt : result == .orderedAscending
            }
        }
    }
}

enum BloomPreferences {
    private static let defaults = UserDefaults.standard
    private static let lastCollectionKey = "capture.lastCollectionID"

    static var lastCaptureCollectionID: UUID? {
        get { defaults.string(forKey: lastCollectionKey).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: lastCollectionKey) }
    }

    static func collectionFilter(_ raw: String?) -> CollectionFilter {
        guard let raw else { return .all }
        if raw == "unfiled" { return .unfiled }
        if let id = UUID(uuidString: raw) { return .collection(id) }
        return .all
    }

    static func rawFilter(_ filter: CollectionFilter) -> String? {
        switch filter {
        case .all: return nil
        case .unfiled: return "unfiled"
        case .collection(let id): return id.uuidString
        }
    }
}

struct RediscoveryHistory: Codable {
    var day: Int
    var proposedIDs: [UUID]
}

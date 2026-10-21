import Foundation

struct NotePlace: Codable, Equatable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
    var kind: PlaceKind?
    var resolvedKind: PlaceKind { kind ?? .other }

    init(name: String, latitude: Double, longitude: Double, kind: PlaceKind? = nil) {
        self.name = name; self.latitude = latitude; self.longitude = longitude; self.kind = kind
    }
    private enum CodingKeys: String, CodingKey { case name, latitude, longitude, kind }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        latitude = try values.decode(Double.self, forKey: .latitude)
        longitude = try values.decode(Double.self, forKey: .longitude)
        kind = try values.decodeIfPresent(String.self, forKey: .kind).flatMap(PlaceKind.init(rawValue:))
    }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.utf8.count <= 4_096 &&
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
    /// Reads explicit pin/destination coordinates, never a map viewport or a social post's guessed location.
    static func from(_ url: URL) -> NotePlace? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              ["http", "https"].contains(components.scheme?.lowercased() ?? "") else { return nil }
        let host = components.host?.lowercased() ?? ""
        let apple = host == "maps.apple.com"
        let google = ["google.com", "google.it", "google.co.uk", "google.fr", "google.es", "google.de"].contains {
            (host == $0 || host == "www." + $0 || host == "maps." + $0) && (components.path.hasPrefix("/maps") || host.hasPrefix("maps."))
        }
        guard apple || google else { return nil }
        let query = Dictionary((components.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
        let keys = apple ? ["coordinate", "ll", "daddr"] : ["query", "q", "destination"]
        for key in keys {
            guard let value = query[key] else { continue }
            let parts = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]) else { continue }
            let label = apple ? (query["name"] ?? query["q"]) : query["label"]
            let place = NotePlace(name: label.flatMap { $0.isEmpty ? nil : $0 } ?? "Luogo salvato", latitude: lat, longitude: lon)
            if place.isValid { return place }
        }
        return nil
    }
}

/// Optional metadata keeps existing notes and backups readable without a data migration.
enum PlaceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case restaurant, cafe, shop, mountain, nature, beach, culture, stay, city, sport, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .restaurant: return "Ristorante"
        case .cafe: return "Bar e caffè"
        case .shop: return "Negozio"
        case .mountain: return "Montagna"
        case .nature: return "Natura e parchi"
        case .beach: return "Spiaggia"
        case .culture: return "Arte e cultura"
        case .stay: return "Dove dormire"
        case .city: return "Città e borghi"
        case .sport: return "Sport"
        case .other: return "Altro luogo"
        }
    }
    var symbol: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        case .shop: return "bag.fill"
        case .mountain: return "mountain.2.fill"
        case .nature: return "leaf.fill"
        case .beach: return "beach.umbrella.fill"
        case .culture: return "building.columns.fill"
        case .stay: return "bed.double.fill"
        case .city: return "building.2.fill"
        case .sport: return "figure.run"
        case .other: return "mappin"
        }
    }
}

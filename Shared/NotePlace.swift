import Foundation

struct NotePlace: Codable, Equatable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
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

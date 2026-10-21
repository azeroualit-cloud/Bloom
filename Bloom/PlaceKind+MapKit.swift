import MapKit

extension PlaceKind {
    /// Uses Apple's POI metadata. A city is recognised only by an exact locality name.
    static func from(_ item: MKMapItem) -> PlaceKind? {
        switch item.pointOfInterestCategory {
        case .restaurant: return .restaurant
        case .cafe, .bakery, .brewery, .winery: return .cafe
        case .store, .foodMarket: return .shop
        case .park, .nationalPark: return .nature
        case .beach: return .beach
        case .museum, .theater, .library: return .culture
        case .hotel, .campground: return .stay
        case .fitnessCenter, .stadium: return .sport
        default:
            guard let name = item.name, let locality = item.placemark.locality,
                  normalized(name) == normalized(locality) else { return nil }
            return .city
        }
    }
    /// An exact name plus a nearby coordinate prevents a neighbouring POI from being misclassified.
    static func matching(_ place: NotePlace, in items: [MKMapItem]) -> PlaceKind? {
        guard let result = items.first(where: {
            normalized($0.name ?? "") == normalized(place.name) &&
            CLLocation(latitude: $0.placemark.coordinate.latitude, longitude: $0.placemark.coordinate.longitude)
                .distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude)) <= 150
        }) else { return nil }
        return from(result)
    }
    static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
    }
}

import SwiftUI
import MapKit

/// Native collision-based clustering follows zoom, while SwiftUI owns the note panel.
@MainActor
struct ClusteredPlacesMap: UIViewRepresentable {
    let places: [PlaceMapAnnotation]
    let selectedID: String?
    let fitRequest: Int
    let select: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> MKMapView {
        let map = PlaceMapCanvas()
        map.delegate = context.coordinator
        map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = true
        map.showsScale = true
        map.register(PlacePinView.self, forAnnotationViewWithReuseIdentifier: "place")
        map.register(PlaceClusterView.self, forAnnotationViewWithReuseIdentifier: "cluster")
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if coordinator.updateAnnotations(map, places: places) {
            coordinator.fit(map, annotations: places, animated: false)
        }
        if fitRequest != coordinator.lastFitRequest {
            coordinator.lastFitRequest = fitRequest
            coordinator.fit(map, annotations: map.annotations.filter { $0 is PlaceMapAnnotation }, animated: false)
        }
        if selectedID == nil {
            for annotation in map.selectedAnnotations { map.deselectAnnotation(annotation, animated: false) }
        }
    }
    static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) { map.delegate = nil }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ClusteredPlacesMap
        var signature: [String] = []
        var lastFitRequest = 0
        init(_ parent: ClusteredPlacesMap) { self.parent = parent }
        /// Metadata refreshes must not reset a camera the user has moved.
        func updateAnnotations(_ map: MKMapView, places: [PlaceMapAnnotation]) -> Bool {
            let geometry = places.map { "\($0.id):\($0.coordinate.latitude):\($0.coordinate.longitude)" }
            if geometry != signature {
                signature = geometry
                map.removeAnnotations(map.annotations)
                map.addAnnotations(places)
                return true
            }
            let byID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
            for case let current as PlaceMapAnnotation in map.annotations {
                guard let updated = byID[current.id], current.title != updated.title || current.count != updated.count || current.kind != updated.kind else { continue }
                current.title = updated.title; current.count = updated.count; current.kind = updated.kind
                (map.view(for: current) as? PlacePinView)?.configure(current)
            }
            for case let cluster as MKClusterAnnotation in map.annotations {
                if let view = map.view(for: cluster) as? PlaceClusterView { view.configure(cluster) }
            }
            return false
        }
        func fit(_ map: MKMapView, annotations: [MKAnnotation], animated: Bool) {
            guard !annotations.isEmpty else { return }
            if map.bounds.isEmpty {
                (map as? PlaceMapCanvas)?.fitOnLayout = { [weak self, weak map] in
                    guard let map else { return }
                    self?.fit(map, annotations: annotations, animated: animated)
                }
                return
            }
            var rect = MKMapRect.null
            for annotation in annotations {
                let point = MKMapPoint(annotation.coordinate)
                rect = rect.union(MKMapRect(x: point.x - 1500, y: point.y - 1500, width: 3000, height: 3000))
            }
            map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 72, left: 48, bottom: 88, right: 48), animated: animated)
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: "cluster", for: cluster) as! PlaceClusterView
                view.configure(cluster)
                return view
            }
            guard let place = annotation as? PlaceMapAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "place", for: place) as! PlacePinView
            view.configure(place)
            return view
        }
        private func updateAccessibility(_ map: MKMapView) {
            for annotation in map.annotations {
                if let view = map.view(for: annotation) { view.isAccessibilityElement = view.cluster == nil }
            }
        }
        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) { updateAccessibility(mapView) }
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) { updateAccessibility(mapView) }
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                fit(mapView, annotations: cluster.memberAnnotations, animated: !UIAccessibility.isReduceMotionEnabled)
                mapView.deselectAnnotation(cluster, animated: false)
            } else if let place = view.annotation as? PlaceMapAnnotation {
                parent.select(place.id)
            }
        }
    }
}

@MainActor
private final class PlaceMapCanvas: MKMapView {
    var fitOnLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        if !bounds.isEmpty, let fit = fitOnLayout { fitOnLayout = nil; fit() }
    }
}

final class PlaceMapAnnotation: NSObject, MKAnnotation {
    let id: String
    let coordinate: CLLocationCoordinate2D
    var title: String?
    var count: Int
    var kind: PlaceKind
    init(id: String, place: NotePlace, count: Int) {
        self.id = id; coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        title = place.name; self.count = count; kind = place.resolvedKind
    }
}

/// MapKit can retain hidden/offscreen annotation views while reclustering. Expose
/// only a visible UIKit target and derive its screen geometry from the actual view.
@MainActor
class PlaceAnnotationView: MKAnnotationView {
    override var isAccessibilityElement: Bool {
        get {
            guard super.isAccessibilityElement, cluster == nil, window != nil, !bounds.isEmpty else { return false }
            var ancestor: UIView? = self
            while let view = ancestor {
                guard !view.isHidden, view.alpha > 0.01 else { return false }
                if let map = view as? MKMapView {
                    return map.bounds.contains(convert(CGPoint(x: bounds.midX, y: bounds.midY), to: map))
                }
                ancestor = view.superview
            }
            return false
        }
        set { super.isAccessibilityElement = newValue }
    }
    override var accessibilityFrame: CGRect {
        get { UIAccessibility.convertToScreenCoordinates(bounds, in: self) }
        set { super.accessibilityFrame = newValue }
    }
    override var accessibilityActivationPoint: CGPoint {
        get { CGPoint(x: accessibilityFrame.midX, y: accessibilityFrame.midY) }
        set { super.accessibilityActivationPoint = newValue }
    }
}

/// Full touch bounds include all decoration, so native collision grouping is reliable.
@MainActor
final class PlaceClusterView: PlaceAnnotationView {
    private let countLabel = UILabel()
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 56, height: 56)
        displayPriority = .required
        collisionMode = .rectangle
        countLabel.frame = CGRect(x: 4, y: 4, width: 48, height: 48)
        countLabel.backgroundColor = BloomBrand.uiAccent
        countLabel.textColor = UIColor { $0.userInterfaceStyle == .dark ? .black : .white }
        countLabel.font = .preferredFont(forTextStyle: .headline)
        countLabel.adjustsFontSizeToFitWidth = true
        countLabel.minimumScaleFactor = 0.6
        countLabel.textAlignment = .center
        countLabel.layer.cornerRadius = 24
        countLabel.layer.borderWidth = 2
        countLabel.layer.borderColor = UIColor(Color.bloomBackground).cgColor
        countLabel.clipsToBounds = true
        addSubview(countLabel)
        isAccessibilityElement = true; accessibilityTraits = .button
        accessibilityIdentifier = "map-cluster"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(_ cluster: MKClusterAnnotation) {
        let places = cluster.memberAnnotations.compactMap { $0 as? PlaceMapAnnotation }
        let notes = places.reduce(0) { $0 + $1.count }
        countLabel.text = "\(places.count)"
        accessibilityLabel = "\(places.count) luoghi, \(ContentLabels.noteCount(notes))"
        accessibilityHint = "Il numero indica i luoghi raggruppati. Tocca per ingrandire"
    }
}

@MainActor
final class PlacePinView: PlaceAnnotationView {
    private let ring = UIView()
    private let glyph = UIImageView()
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        clusteringIdentifier = "bloom-places"
        collisionMode = .rectangle
        displayPriority = .defaultLow
        ring.frame = CGRect(x: 6, y: 6, width: 32, height: 32)
        ring.backgroundColor = UIColor(Color.bloomBackground)
        ring.layer.cornerRadius = 16
        ring.layer.borderWidth = 2
        ring.layer.borderColor = BloomBrand.uiAccent.cgColor
        glyph.frame = CGRect(x: 12, y: 12, width: 20, height: 20)
        glyph.contentMode = .scaleAspectFit
        glyph.tintColor = BloomBrand.uiAccent
        addSubview(ring); addSubview(glyph)
        isAccessibilityElement = true; accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        ring.layer.borderWidth = selected ? 4 : 2
    }
    func configure(_ place: PlaceMapAnnotation) {
        glyph.image = UIImage(systemName: place.kind.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        accessibilityIdentifier = "map-marker-\(place.id)"
        accessibilityLabel = "\(place.title ?? "Luogo"), \(place.kind.label), \(ContentLabels.noteCount(place.count))"
        accessibilityHint = "Mostra le note salvate in questo luogo"
    }
}

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
        /// Thumbnail/title refreshes must not reset a camera the user has moved.
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
                guard let updated = byID[current.id], current.title != updated.title || current.count != updated.count || current.imageData != updated.imageData else { continue }
                current.title = updated.title; current.count = updated.count; current.imageData = updated.imageData
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
    var imageData: Data?
    init(id: String, place: NotePlace, count: Int, imageData: Data?) {
        self.id = id; coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        title = place.name; self.count = count; self.imageData = imageData
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

/// A full-size UIKit target avoids MKMarkerAnnotationView's tiny internal accessibility hit region.
@MainActor
final class PlaceClusterView: PlaceAnnotationView {
    private let countLabel = UILabel()
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 52, height: 64)
        centerOffset = CGPoint(x: 0, y: -32)
        displayPriority = .required
        collisionMode = .circle
        let anchor = UIImageView(image: UIImage(systemName: "triangle.fill"))
        anchor.frame = CGRect(x: 19, y: 47, width: 14, height: 14)
        anchor.transform = CGAffineTransform(rotationAngle: .pi)
        anchor.tintColor = .systemIndigo
        addSubview(anchor)
        countLabel.frame = CGRect(x: 2, y: 0, width: 48, height: 48)
        countLabel.backgroundColor = .systemIndigo
        countLabel.textColor = .white
        countLabel.font = .preferredFont(forTextStyle: .headline)
        countLabel.adjustsFontSizeToFitWidth = true
        countLabel.minimumScaleFactor = 0.6
        countLabel.textAlignment = .center
        countLabel.layer.cornerRadius = 24
        countLabel.layer.borderWidth = 2
        countLabel.layer.borderColor = UIColor.white.cgColor
        countLabel.clipsToBounds = true
        addSubview(countLabel)
        isAccessibilityElement = true; accessibilityTraits = .button
        accessibilityIdentifier = "map-cluster"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(_ cluster: MKClusterAnnotation) {
        let notes = cluster.memberAnnotations.compactMap { $0 as? PlaceMapAnnotation }.reduce(0) { $0 + $1.count }
        countLabel.text = "\(notes)"
        accessibilityLabel = "\(cluster.memberAnnotations.count) luoghi, \(ContentLabels.noteCount(notes))"
        accessibilityHint = "Ingrandisci per separare i luoghi"
    }
}

@MainActor
final class PlacePinView: PlaceAnnotationView {
    private let thumbnail = UIImageView()
    private let badge = UILabel()
    private let anchor = UIImageView(image: UIImage(systemName: "triangle.fill"))
    private var decode: Task<Void, Never>?
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 48, height: 60)
        centerOffset = CGPoint(x: 0, y: -30)
        clusteringIdentifier = "bloom-places"
        collisionMode = .rectangle
        displayPriority = .defaultLow
        thumbnail.frame = CGRect(x: 2, y: 2, width: 44, height: 44)
        thumbnail.contentMode = .scaleAspectFill
        thumbnail.clipsToBounds = true
        thumbnail.layer.cornerRadius = 9
        thumbnail.layer.borderWidth = 2
        thumbnail.layer.borderColor = UIColor.label.cgColor
        thumbnail.backgroundColor = UIColor(Color.bloomSurface)
        thumbnail.tintColor = UIColor(Color.accentColor)
        anchor.frame = CGRect(x: 17, y: 44, width: 14, height: 12)
        anchor.transform = CGAffineTransform(rotationAngle: .pi)
        anchor.tintColor = UIColor.label
        badge.frame = CGRect(x: 28, y: -5, width: 24, height: 24)
        badge.font = .preferredFont(forTextStyle: .caption1)
        badge.textAlignment = .center; badge.adjustsFontSizeToFitWidth = true
        badge.backgroundColor = UIColor(Color.accentColor); badge.textColor = .black
        badge.layer.cornerRadius = 12; badge.clipsToBounds = true
        addSubview(anchor); addSubview(thumbnail); addSubview(badge)
        isAccessibilityElement = true; accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func prepareForReuse() { super.prepareForReuse(); decode?.cancel(); thumbnail.image = nil }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        thumbnail.layer.borderWidth = selected ? 3 : 2
        thumbnail.layer.borderColor = (selected ? UIColor(Color.accentColor) : UIColor.label).cgColor
    }
    func configure(_ place: PlaceMapAnnotation) {
        decode?.cancel()
        accessibilityIdentifier = "map-marker-\(place.id)"
        accessibilityLabel = "\(place.title ?? "Luogo"), \(ContentLabels.noteCount(place.count))"
        accessibilityHint = "Mostra le note salvate in questo luogo"
        badge.text = "\(place.count)"; badge.isHidden = place.count < 2
        thumbnail.contentMode = .scaleAspectFit
        thumbnail.image = UIImage(systemName: "mappin")
        decode = Task { [weak self] in
            let image = await CachedPreviewImage.decode(place.imageData, maximumPixel: 144)
            guard !Task.isCancelled else { return }
            if let image {
                self?.thumbnail.contentMode = .scaleAspectFill
                self?.thumbnail.image = image
            }
        }
    }
}

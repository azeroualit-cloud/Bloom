import XCTest
import MapKit
import SwiftUI
@testable import Bloom

final class PresentationTests: XCTestCase {
    func testTextPresentationPreservesStructuredDocumentsAndRecognisesShortQuotes() {
        XCTAssertEqual(TextNoteStyle.classify("San Giuliano Terme"), .statement)
        XCTAssertEqual(TextNoteStyle.classify("> Le cose belle crescono un giorno alla volta."), .quote)
        XCTAssertEqual(TextNoteStyle.classify("# Un titolo breve"), .statement)
        XCTAssertEqual(TextNoteStyle.displayText("> **Una citazione**"), "**Una citazione**")
        for source in ["1. Gel\n2. Curl", "- Primo\n- Secondo", "| A | B |\n| --- | --- |\n| 1 | 2 |", "```swift\nlet x = 1\n```", String(repeating: "Una nota lunga. ", count: 40)] {
            XCTAssertEqual(TextNoteStyle.classify(source), .document, source)
        }
    }
    func testPlaceKindsDecodeOldAndFutureBackupsWithoutLosingCoordinates() throws {
        let old = Data(#"{"name":"Roma","latitude":41.89,"longitude":12.49}"#.utf8)
        let legacy = try JSONDecoder().decode(NotePlace.self, from: old)
        XCTAssertNil(legacy.kind)
        XCTAssertEqual(legacy.resolvedKind, .other)
        var updated = legacy; updated.kind = .culture
        XCTAssertEqual(try JSONDecoder().decode(NotePlace.self, from: JSONEncoder().encode(updated)), updated)
        let future = Data(#"{"name":"Roma","latitude":41.89,"longitude":12.49,"kind":"future-category"}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(NotePlace.self, from: future), legacy)
    }
    func testPlaceKindUsesMapMetadataRatherThanGuessingFromAName() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 41.89, longitude: 12.49)))
        item.name = "Montagna Restaurant"
        XCTAssertNil(PlaceKind.from(item))
        item.pointOfInterestCategory = .restaurant
        XCTAssertEqual(PlaceKind.from(item), .restaurant)
        item.pointOfInterestCategory = .store
        XCTAssertEqual(PlaceKind.from(item), .shop)
    }

    func testMarkdownTableKeepsColumnsEscapesAndRaggedRows() throws {
        let source = "## Contatti\n\n| Chi | Recapito |\n| :--- | ---: |\n| Helpdesk | 0100000000 |\n| A\\|B | `x|y` |\n| Solo |\n\n###### Because\nSpiega il **Perché**"
        let blocks = MarkdownBlock.parse(source)
        XCTAssertEqual(blocks.count, 4)
        guard case .heading(2) = blocks[0].kind else { return XCTFail("Missing heading") }
        guard case .table(let headers, let rows) = blocks[1].kind else { return XCTFail("Missing table") }
        XCTAssertEqual(headers, ["Chi", "Recapito"])
        XCTAssertEqual(rows, [["Helpdesk", "0100000000"], ["A|B", "`x|y`"], ["Solo", ""]])
        guard case .heading(6) = blocks[2].kind else { return XCTFail("H6 must remain a heading") }
        XCTAssertEqual(blocks[2].text, "Because")
        XCTAssertEqual(blocks[3].text, "Spiega il **Perché**")
    }
    func testInvalidTableRemainsTextAndFencedCodeIsNeverParsedAsTable() {
        let blocks = MarkdownBlock.parse("| A | B |\n| -- | --- |\n\n```md\n| A | B |\n| --- | --- |\n```")
        XCTAssertEqual(blocks.count, 3)
        guard case .paragraph = blocks[0].kind else { return XCTFail("Malformed table must stay readable") }
        guard case .code = blocks[2].kind else { return XCTFail("Code must stay literal") }
        XCTAssertTrue(blocks[2].text.contains("| --- |"))
    }
    func testSourceIsNotChangedAndExtraCellsAreNotLost() {
        let source = "| A | B |\n| --- | --- |\n| 1 | 2 | 3 |"
        guard case .table(let headers, let rows) = MarkdownBlock.parse(source).first?.kind else { return XCTFail("Missing table") }
        XCTAssertEqual(headers, ["A", "B", ""])
        XCTAssertEqual(rows, [["1", "2", "3"]])
    }
    func testDocumentSearchFindsTableCellsAndIsCaseInsensitive() {
        let text = "# Intro\n\n| Chi | Recapito |\n| --- | --- |\n| Helpdesk | 0100000000 |\n\nFine"
        XCTAssertEqual(MarkdownBlock.firstMatch(in: text, query: "HELPDESK"), 1)
        XCTAssertEqual(MarkdownBlock.firstMatch(in: text, query: "Fine"), 2)
        XCTAssertNil(MarkdownBlock.firstMatch(in: text, query: ""))
        XCTAssertNil(MarkdownBlock.firstMatch(in: text, query: "Missing"))
    }
    func testLabelsDistinguishCountsAndSafeSocialHostFallbacks() {
        XCTAssertEqual(ContentLabels.noteCount(0), "0 note")
        XCTAssertEqual(ContentLabels.noteCount(1), "1 nota")
        XCTAssertEqual(ContentLabels.noteCount(76), "76 note")
        XCTAssertEqual(ContentLabels.linkTitle(URL(string: "https://vm.tiktok.com/test/")!), "Video TikTok")
        XCTAssertEqual(ContentLabels.linkTitle(URL(string: "https://www.instagram.com/p/test/")!), "Post Instagram")
        XCTAssertEqual(ContentLabels.linkTitle(URL(string: "https://tiktok.com.evil.example/test")!), "Link da tiktok.com.evil.example")
    }
    @MainActor
    func testClusterHasAFullTouchTargetAndCountsNotesAcrossPlaces() {
        let first = PlaceMapAnnotation(id: "a", place: NotePlace(name: "A", latitude: 41.89, longitude: 12.49), count: 3)
        let second = PlaceMapAnnotation(id: "b", place: NotePlace(name: "B", latitude: 41.90, longitude: 12.50), count: 1)
        let cluster = MKClusterAnnotation(memberAnnotations: [first, second])
        let view = PlaceClusterView(annotation: cluster, reuseIdentifier: "test")
        view.configure(cluster)
        XCTAssertGreaterThanOrEqual(view.bounds.width, 44)
        XCTAssertGreaterThanOrEqual(view.bounds.height, 44)
        XCTAssertEqual(view.accessibilityLabel, "2 luoghi, 4 note")
        XCTAssertEqual(view.accessibilityIdentifier, "map-cluster")
        XCTAssertEqual(view.subviews.compactMap { $0 as? UILabel }.first?.text, "2", "Visible cluster counts places, while accessibility also reports notes")
    }
    @MainActor
    func testMarkdownKeyboardActionsStayEvenAtNarrowWidthsAndEditTheSelection() throws {
        let editor = LiveMarkdownEditor(text: .constant("abc"), focused: .constant(false))
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        coordinator.editor = textView
        coordinator.installToolbar(textView)
        let bar = try XCTUnwrap(textView.inputAccessoryView)
        let stack = try XCTUnwrap(bar.subviews.compactMap { $0 as? UIStackView }.first)
        let buttons = stack.arrangedSubviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(buttons.count, 6)
        for width in [CGFloat(320), CGFloat(390)] {
            bar.frame.size.width = width
            bar.setNeedsLayout(); bar.layoutIfNeeded()
            for button in buttons {
                XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
                XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                XCTAssertEqual(button.bounds.width, buttons[0].bounds.width, accuracy: 0.5)
            }
        }
        textView.text = "abc"
        textView.selectedRange = NSRange(location: 0, length: 3)
        buttons[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(textView.text, "**abc**")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 2, length: 3))
    }
    @MainActor
    func testMapAnnotationAccessibilityUsesVisibleViewGeometry() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        window.rootViewController = root
        window.isHidden = false
        let map = MKMapView(frame: CGRect(x: 0, y: 100, width: 390, height: 600))
        root.view.addSubview(map)
        let pin = PlacePinView(annotation: nil, reuseIdentifier: "accessibility")
        pin.frame.origin = CGPoint(x: 100, y: 150)
        map.addSubview(pin)
        XCTAssertTrue(pin.isAccessibilityElement)
        XCTAssertEqual(pin.accessibilityFrame, UIAccessibility.convertToScreenCoordinates(pin.bounds, in: pin))
        XCTAssertEqual(pin.accessibilityActivationPoint, CGPoint(x: pin.accessibilityFrame.midX, y: pin.accessibilityFrame.midY))
        pin.isHidden = true
        XCTAssertFalse(pin.isAccessibilityElement)
        pin.isHidden = false
        pin.frame.origin.x = -100
        XCTAssertFalse(pin.isAccessibilityElement)
        pin.removeFromSuperview()
        XCTAssertFalse(pin.isAccessibilityElement)
        window.isHidden = true
    }
    @MainActor
    func testMapMetadataRefreshKeepsTheCameraAndUpdatesThePin() {
        let place = NotePlace(name: "Roma", latitude: 41.89, longitude: 12.49)
        let original = PlaceMapAnnotation(id: "rome", place: place, count: 1)
        let parent = ClusteredPlacesMap(places: [original], selectedID: nil, fitRequest: 0) { _ in }
        let coordinator = parent.makeCoordinator()
        let map = MKMapView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        XCTAssertTrue(coordinator.updateAnnotations(map, places: [original]))
        coordinator.fit(map, annotations: [original], animated: false)
        let camera = map.visibleMapRect
        var classified = place; classified.kind = .culture
        let updated = PlaceMapAnnotation(id: "rome", place: classified, count: 2)
        XCTAssertFalse(coordinator.updateAnnotations(map, places: [updated]))
        XCTAssertEqual(map.visibleMapRect.origin.x, camera.origin.x)
        XCTAssertEqual(map.visibleMapRect.origin.y, camera.origin.y)
        XCTAssertEqual(map.visibleMapRect.size.width, camera.size.width)
        XCTAssertEqual(map.visibleMapRect.size.height, camera.size.height)
        XCTAssertEqual(original.count, 2)
        XCTAssertEqual(original.kind, .culture)
    }
    @MainActor
    func testMapPinsKeepExactCoordinatesAndAllowNativeClustering() {
        let place = NotePlace(name: "Colosseo", latitude: 41.8902, longitude: 12.4922)
        let annotation = PlaceMapAnnotation(id: "rome", place: place, count: 3)
        XCTAssertEqual(annotation.coordinate.latitude, place.latitude)
        XCTAssertEqual(annotation.coordinate.longitude, place.longitude)
        let parent = ClusteredPlacesMap(places: [annotation], selectedID: nil, fitRequest: 0) { _ in }
        let coordinator = parent.makeCoordinator()
        let map = MKMapView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let pin = PlacePinView(annotation: annotation, reuseIdentifier: "test")
        pin.configure(annotation)
        XCTAssertEqual(pin.clusteringIdentifier, "bloom-places")
        XCTAssertEqual(pin.centerOffset, .zero)
        XCTAssertGreaterThanOrEqual(pin.bounds.width, 44)
        XCTAssertEqual(pin.accessibilityIdentifier, "map-marker-rome")
        // Fitting is independent of downloaded map tiles.
        coordinator.fit(map, annotations: [annotation], animated: false)
        XCTAssertTrue(map.visibleMapRect.contains(MKMapPoint(annotation.coordinate)))
    }
}

import XCTest
import MapKit
@testable import Bloom

final class PresentationTests: XCTestCase {
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
        let first = PlaceMapAnnotation(id: "a", place: NotePlace(name: "A", latitude: 41.89, longitude: 12.49), count: 3, imageData: nil)
        let second = PlaceMapAnnotation(id: "b", place: NotePlace(name: "B", latitude: 41.90, longitude: 12.50), count: 1, imageData: nil)
        let cluster = MKClusterAnnotation(memberAnnotations: [first, second])
        let view = PlaceClusterView(annotation: cluster, reuseIdentifier: "test")
        view.configure(cluster)
        XCTAssertGreaterThanOrEqual(view.bounds.width, 44)
        XCTAssertGreaterThanOrEqual(view.bounds.height, 44)
        XCTAssertEqual(view.accessibilityLabel, "2 luoghi, 4 note")
        XCTAssertEqual(view.accessibilityIdentifier, "map-cluster")
    }
    @MainActor
    func testMapMetadataRefreshKeepsTheCameraAndUpdatesThePin() {
        let place = NotePlace(name: "Roma", latitude: 41.89, longitude: 12.49)
        let original = PlaceMapAnnotation(id: "rome", place: place, count: 1, imageData: nil)
        let parent = ClusteredPlacesMap(places: [original], selectedID: nil, fitRequest: 0) { _ in }
        let coordinator = parent.makeCoordinator()
        let map = MKMapView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        XCTAssertTrue(coordinator.updateAnnotations(map, places: [original]))
        coordinator.fit(map, annotations: [original], animated: false)
        let camera = map.visibleMapRect
        let updated = PlaceMapAnnotation(id: "rome", place: place, count: 2, imageData: Data([0, 1, 2]))
        XCTAssertFalse(coordinator.updateAnnotations(map, places: [updated]))
        XCTAssertEqual(map.visibleMapRect.origin.x, camera.origin.x)
        XCTAssertEqual(map.visibleMapRect.origin.y, camera.origin.y)
        XCTAssertEqual(map.visibleMapRect.size.width, camera.size.width)
        XCTAssertEqual(map.visibleMapRect.size.height, camera.size.height)
        XCTAssertEqual(original.count, 2)
        XCTAssertEqual(original.imageData, updated.imageData)
    }
    @MainActor
    func testMapPinsKeepExactCoordinatesAndAllowNativeClustering() {
        let place = NotePlace(name: "Colosseo", latitude: 41.8902, longitude: 12.4922)
        let annotation = PlaceMapAnnotation(id: "rome", place: place, count: 3, imageData: nil)
        XCTAssertEqual(annotation.coordinate.latitude, place.latitude)
        XCTAssertEqual(annotation.coordinate.longitude, place.longitude)
        let parent = ClusteredPlacesMap(places: [annotation], selectedID: nil, fitRequest: 0) { _ in }
        let coordinator = parent.makeCoordinator()
        let map = MKMapView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let pin = PlacePinView(annotation: annotation, reuseIdentifier: "test")
        pin.configure(annotation)
        XCTAssertEqual(pin.clusteringIdentifier, "bloom-places")
        XCTAssertEqual(pin.accessibilityIdentifier, "map-marker-rome")
        // Fitting is independent of downloaded map tiles.
        coordinator.fit(map, annotations: [annotation], animated: false)
        XCTAssertTrue(map.visibleMapRect.contains(MKMapPoint(annotation.coordinate)))
    }
}

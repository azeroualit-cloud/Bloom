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
    func testLabelsDistinguishCountsAndSafeSocialHostFallbacks() {
        XCTAssertEqual(ContentLabels.noteCount(0), "0 note")
        XCTAssertEqual(ContentLabels.noteCount(1), "1 nota")
        XCTAssertEqual(ContentLabels.noteCount(76), "76 note")
        XCTAssertEqual(ContentLabels.linkTitle(URL(string: "https://vm.tiktok.com/test/")!), "Video TikTok")
        XCTAssertEqual(ContentLabels.linkTitle(URL(string: "https://www.instagram.com/p/test/")!), "Post Instagram")
        XCTAssertEqual(ContentLabels.linkTitle(URL(string: "https://tiktok.com.evil.example/test")!), "Link da tiktok.com.evil.example")
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

import XCTest
import SwiftData
@testable import Bloom

final class CaptureTests: XCTestCase {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }

    func testRejectsNonWebURLs() {
        for value in ["file:///secret", "javascript:alert(1)", "https://"] {
            XCTAssertThrowsError(try LinkValidation.validate(URL(string: value)!))
        }
    }

    @MainActor
    func testCapturePersistsPrivatelyAcrossReopenWithoutDuplicates() throws {
        let root = try temporaryRoot()
        let url = URL(string: "https://example.com/article?q=hello#part")!
        do {
            let container = try LinkStore.container(at: root)
            XCTAssertTrue(try LinkStore.capture(url, into: container.mainContext))
            XCTAssertFalse(try LinkStore.capture(url, into: container.mainContext))
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<CapturedLink>()), 1)
        }
        let reopened = try LinkStore.container(at: root)
        let links = try reopened.mainContext.fetch(FetchDescriptor<CapturedLink>())
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.urlString, url.absoluteString)
    }

    @MainActor
    func testRejectedCaptureDoesNotWrite() throws {
        let container = try LinkStore.container(at: temporaryRoot())
        XCTAssertThrowsError(try LinkStore.capture(URL(string: "file:///private")!, into: container.mainContext))
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<CapturedLink>()), 0)
    }

    func testRoutePreservesURLQueryAndFragment() throws {
        let target = URL(string: "https://example.com/?a=1&b=two%20words#part")!
        var route = URLComponents()
        route.scheme = "bloom"
        route.host = "capture"
        route.queryItems = [URLQueryItem(name: "url", value: target.absoluteString)]
        XCTAssertEqual(try CaptureRoute.link(from: XCTUnwrap(route.url)), target)
    }

    func testRejectsAmbiguousOrUnsafeRoutes() {
        for raw in ["bloom://capture?url=file:///private", "bloom://delete?url=https://example.com",
                    "bloom://capture?url=https://example.com&url=https://other.com", "bloom://capture",
                    "bloom://capture/other?url=https://example.com"] {
            XCTAssertThrowsError(try CaptureRoute.link(from: URL(string: raw)!))
        }
    }
}

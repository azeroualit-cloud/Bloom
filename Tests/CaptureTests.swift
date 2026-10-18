import XCTest
import SwiftData
@testable import Bloom

final class CaptureTests: XCTestCase {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }

    func testRejectsNonWebURLs() {
        for value in ["file:///secret", "javascript:alert(1)", "https://"] {
            XCTAssertThrowsError(try LinkValidation.validate(URL(string: value)!))
        }
    }

    @MainActor
    func testCaptureSurvivesReopenAndImportsOnce() throws {
        let root = try temporaryRoot()
        let url = URL(string: "https://example.com/article?q=hello#part")!
        try CaptureInbox(root: root).save(url)
        let inbox = try CaptureInbox(root: root)
        let originalFile = try XCTUnwrap(inbox.pendingFiles().first)
        let originalData = try Data(contentsOf: originalFile)
        do {
            let container = try LinkStore.container(at: root)
            try LinkStore.importInbox(inbox, into: container.mainContext)
            XCTAssertTrue(try inbox.pendingFiles().isEmpty)
            // Simulate a crash after database save but before inbox deletion.
            try originalData.write(to: originalFile, options: .atomic)
            try LinkStore.importInbox(inbox, into: container.mainContext)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<CapturedLink>()), 1)
        }
        let reopened = try LinkStore.container(at: root)
        let links = try reopened.mainContext.fetch(FetchDescriptor<CapturedLink>())
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.urlString, url.absoluteString)
    }

    @MainActor
    func testCorruptCaptureIsRetainedForRecovery() throws {
        let root = try temporaryRoot()
        let inbox = try CaptureInbox(root: root)
        let file = inbox.directory.appendingPathComponent("broken.json")
        try Data("broken".utf8).write(to: file)
        let container = try LinkStore.container(at: root)
        XCTAssertThrowsError(try LinkStore.importInbox(inbox, into: container.mainContext))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<CapturedLink>()), 0)
    }
}

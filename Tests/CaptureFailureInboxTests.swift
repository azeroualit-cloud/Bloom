import XCTest
@testable import Bloom

@MainActor
final class CaptureFailureInboxTests: XCTestCase {
    func testPendingFailuresSurviveReopenAndAreConsumedOnceInOrder() throws {
        let suite = "BloomCaptureFailure-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = URL(string: "https://example.com/first")!
        let second = URL(string: "https://example.com/second")!
        CaptureFailureInbox.record(url: first, message: "Offline", defaults: defaults)
        CaptureFailureInbox.record(url: second, message: "Store locked", defaults: defaults)
        let reopened = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertEqual(CaptureFailureInbox.take(defaults: reopened), .init(url: first, message: "Offline"))
        XCTAssertEqual(CaptureFailureInbox.take(defaults: reopened), .init(url: second, message: "Store locked"))
        XCTAssertNil(CaptureFailureInbox.take(defaults: reopened))
    }
    func testRepeatedFailureForSameLinkKeepsLatestErrorWithoutDuplicates() throws {
        let suite = "BloomCaptureFailure-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = URL(string: "https://example.com")!
        CaptureFailureInbox.record(url: url, message: "First failure", defaults: defaults)
        CaptureFailureInbox.record(url: url, message: "Retry failed", defaults: defaults)
        XCTAssertEqual(CaptureFailureInbox.take(defaults: defaults)?.message, "Retry failed")
        XCTAssertNil(CaptureFailureInbox.take(defaults: defaults))
    }
}

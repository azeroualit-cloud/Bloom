import XCTest
@testable import Bloom

final class StorageDiagnosticsTests: XCTestCase {
    func testPrivateStoreReportExcludesErrorDetails() {
        let path = "/private/secret-container/Bloom.store"
        let error = NSError(domain: NSCocoaErrorDomain, code: 513,
                            userInfo: [NSFilePathErrorKey: path,
                                       NSLocalizedDescriptionKey: "Private content"])
        let report = StorageDiagnostics(appInfo: ["CFBundleVersion": "3"], error: error).report
        XCTAssertTrue(report.contains("App Groups: non richiesti"))
        XCTAssertTrue(report.contains("NSCocoaErrorDomain / 513"))
        XCTAssertFalse(report.contains(path))
        XCTAssertFalse(report.contains("Private content"))
    }
}

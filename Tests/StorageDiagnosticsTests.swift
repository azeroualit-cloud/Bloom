import XCTest
@testable import Bloom

final class StorageDiagnosticsTests: XCTestCase {
    func testUnresolvedGroupCannotBeUsedForContainerLookup() {
        XCTAssertNil(StorageDiagnostics.configuredGroup(in: [:]))
        XCTAssertNil(StorageDiagnostics.configuredGroup(in: ["BloomAppGroup": "  "]))
        XCTAssertNil(StorageDiagnostics.configuredGroup(in: ["BloomAppGroup": "$(APP_GROUP_IDENTIFIER)"]))
        XCTAssertEqual(StorageDiagnostics.configuredGroup(in: ["BloomAppGroup": "group.bloom"]), "group.bloom")
    }

    func testReportIdentifiesMismatchedExtensionWithoutLeakingErrorDetails() {
        let privatePath = "/private/secret-container/Bloom.store"
        let error = NSError(domain: NSCocoaErrorDomain, code: 513,
                            userInfo: [NSFilePathErrorKey: privatePath,
                                       NSLocalizedDescriptionKey: "Private content"])
        let report = StorageDiagnostics(
            appInfo: ["BloomAppGroup": "group.bloom", "CFBundleVersion": "2"],
            extensionInfo: ["BloomAppGroup": "group.other"],
            stage: .database, error: error
        ).report
        XCTAssertTrue(report.contains("Gruppi dichiarati coincidenti: no"))
        XCTAssertTrue(report.contains("NSCocoaErrorDomain / 513"))
        XCTAssertTrue(report.contains("Apertura database SwiftData"))
        XCTAssertFalse(report.contains(privatePath))
        XCTAssertFalse(report.contains("Private content"))
    }

    func testMissingExtensionAndContainerDenialAreDistinctFromDatabaseFailure() {
        let report = StorageDiagnostics(appInfo: ["BloomAppGroup": "group.bloom"],
                                        extensionInfo: nil, stage: .container,
                                        error: CaptureError.appGroupUnavailable).report
        XCTAssertTrue(report.contains("Estensione incorporata: non rilevata"))
        XCTAssertTrue(report.contains("nessun URL restituito da iOS"))
        XCTAssertTrue(report.contains("Gruppi dichiarati coincidenti: non verificabile"))
        XCTAssertTrue(report.contains("autorizzazioni del profilo: non verificati"))
    }
}

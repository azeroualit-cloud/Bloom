import XCTest
import SwiftData
@testable import Bloom

private actor PKMSDropboxFixture: DropboxServing {
    private var text = "# Originale\nTesto"
    private var revision = "r1"
    private var offline = false
    private var missing = false
    private var uploads = 0
    private var loseNextReply = false
    private var listingOverride: [DropboxEntry]?
    func entry() -> DropboxEntry {
        DropboxEntry(tag: missing ? "deleted" : "file", name: "Nota.md", id: missing ? nil : "id:note", pathLower: "/pkms/nota.md", pathDisplay: "/PKMS/Nota.md", rev: missing ? nil : revision, size: text.utf8.count)
    }
    func list(path: String, recursive: Bool, cursor: String?) async throws -> DropboxListing {
        if offline { throw URLError(.notConnectedToInternet) }
        return DropboxListing(entries: listingOverride ?? [entry()], cursor: "cursor", hasMore: false)
    }
    func download(id: String) async throws -> DropboxDownload {
        if offline { throw URLError(.notConnectedToInternet) }
        if missing { throw DropboxFailure.remoteMissing }
        return DropboxDownload(text: text, metadata: entry())
    }
    func upload(path: String, revision: String, text: String) async throws -> DropboxEntry {
        if offline { throw URLError(.notConnectedToInternet) }
        if missing { throw DropboxFailure.remoteMissing }
        guard revision == self.revision else { throw DropboxFailure.conflict }
        self.text = text; self.revision += "u"; uploads += 1
        if loseNextReply { loseNextReply = false; throw URLError(.networkConnectionLost) }
        return entry()
    }
    func modifyRemotely(_ text: String) { self.text = text; revision += "x" }
    func setOffline(_ value: Bool) { offline = value }
    func deleteRemotely() { missing = true }
    func loseUploadReplyOnce() { loseNextReply = true }
    func setListing(_ entries: [DropboxEntry]) { listingOverride = entries }
    func uploadedCount() -> Int { uploads }
    func remoteText() -> String { text }
}

@MainActor
final class PKMSTests: XCTestCase {
    private func disk() throws -> PKMSDisk {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return try PKMSDisk(root: root)
    }
    func testOfflineDraftSurvivesRestartThenUploadsOriginalFile() async throws {
        let disk = try disk(), api = PKMSDropboxFixture()
        let store = PKMSStore(api: api, disk: disk, connected: true)
        await store.selectRoot("/pkms")
        let entry = await api.entry()
        await store.open(entry)
        await api.setOffline(true)
        let markdown = "---\ntags: [test]\n---\n# Modificato\r\n- [ ] Da fare\n"
        store.update(id: entry.identity, text: markdown)
        await store.sync()
        XCTAssertEqual(store.pendingCount, 1)
        XCTAssertNotNil(store.error)
        let restarted = PKMSStore(api: api, disk: disk, connected: true)
        XCTAssertEqual(restarted.documents[entry.identity]?.text, markdown)
        await api.setOffline(false)
        await restarted.sync()
        let remote = await api.remoteText()
        XCTAssertEqual(remote, markdown)
        XCTAssertEqual(restarted.pendingCount, 0)
        XCTAssertNil(restarted.error)
        XCTAssertEqual(try disk.loadDocuments()[entry.identity]?.syncedText, markdown)
    }
    func testLostUploadReplyAndMoreTypingDoNotCreateFalseConflict() async throws {
        let api = PKMSDropboxFixture(), disk = try disk()
        let store = PKMSStore(api: api, disk: disk, connected: true)
        await store.selectRoot("/pkms")
        let entry = await api.entry()
        await store.open(entry)
        store.update(id: entry.identity, text: "First draft")
        await api.loseUploadReplyOnce()
        await store.sync()
        XCTAssertEqual(store.documents[entry.identity]?.attemptedText, "First draft")
        let restarted = PKMSStore(api: api, disk: disk, connected: true)
        restarted.update(id: entry.identity, text: "First draft with more typing")
        await restarted.sync()
        let remote = await api.remoteText()
        XCTAssertEqual(remote, "First draft with more typing")
        XCTAssertFalse(try XCTUnwrap(restarted.documents[entry.identity]).hasConflict)
        XCTAssertEqual(restarted.pendingCount, 0)
    }
    func testConcurrentEditPreservesBothVersionsUntilExplicitChoice() async throws {
        let api = PKMSDropboxFixture(), disk = try disk()
        let store = PKMSStore(api: api, disk: disk, connected: true)
        await store.selectRoot("/pkms")
        let entry = await api.entry()
        await store.open(entry)
        store.update(id: entry.identity, text: "Versione telefono")
        await api.modifyRemotely("Versione PC")
        await store.sync()
        XCTAssertEqual(store.documents[entry.identity]?.text, "Versione telefono")
        XCTAssertEqual(store.documents[entry.identity]?.conflictText, "Versione PC")
        let uploadsBefore = await api.uploadedCount()
        XCTAssertEqual(uploadsBefore, 0)
        let restarted = PKMSStore(api: api, disk: disk, connected: true)
        XCTAssertEqual(restarted.documents[entry.identity]?.conflictText, "Versione PC")
        restarted.resolve(id: entry.identity, keepLocal: true)
        await restarted.sync()
        let remote = await api.remoteText()
        XCTAssertEqual(remote, "Versione telefono")
        XCTAssertFalse(try XCTUnwrap(restarted.documents[entry.identity]).hasConflict)
        let recovery = disk.root.appendingPathComponent("Recovery")
        XCTAssertGreaterThan(try FileManager.default.contentsOfDirectory(atPath: recovery.path).count, 0)
    }
    func testRemoteDeletionNeverRecreatesFileOrDiscardsLocalDraft() async throws {
        let api = PKMSDropboxFixture(), disk = try disk()
        let store = PKMSStore(api: api, disk: disk, connected: true)
        await store.selectRoot("/pkms")
        let entry = await api.entry()
        await store.open(entry)
        store.update(id: entry.identity, text: "Da recuperare")
        await api.deleteRemotely()
        await store.sync()
        let document = try XCTUnwrap(store.documents[entry.identity])
        XCTAssertEqual(document.text, "Da recuperare")
        XCTAssertTrue(document.remoteDeleted)
        XCTAssertEqual(store.pendingCount, 0) // Preserved recovery copies are not uploadable drafts.
        let uploads = await api.uploadedCount()
        XCTAssertEqual(uploads, 0)
        XCTAssertTrue(store.index.entries.isEmpty)
        XCTAssertEqual(try disk.loadDocuments()[entry.identity]?.text, "Da recuperare")
    }
    func testFileReplacingFolderRemovesOldDescendantsFromTheIndex() async throws {
        let api = PKMSDropboxFixture(), disk = try disk()
        let folder = DropboxEntry(tag: "folder", name: "Lavoro", id: "id:folder", pathLower: "/pkms/lavoro", pathDisplay: nil, rev: nil, size: nil)
        let child = DropboxEntry(tag: "file", name: "Child.md", id: "id:child", pathLower: "/pkms/lavoro/child.md", pathDisplay: nil, rev: "r1", size: 5)
        await api.setListing([folder, child])
        let store = PKMSStore(api: api, disk: disk, connected: true)
        await store.selectRoot("/pkms")
        XCTAssertEqual(store.index.entries.count, 2)
        let replacement = DropboxEntry(tag: "file", name: "Lavoro", id: "id:replacement", pathLower: folder.pathLower, pathDisplay: nil, rev: "r2", size: 5)
        await api.setListing([replacement])
        await store.sync()
        XCTAssertTrue(store.index.entries.isEmpty)
    }
    func testAcknowledgingUploadRetainsNewerTypingAndRemoteEchoIsNotConflict() {
        var document = PKMSDocument(id: "id:note", path: "/nota.md", text: "Draft 2", revision: "r1", syncedText: "Original")
        document.acknowledge(uploaded: "Draft 1", revision: "r2")
        XCTAssertEqual(document.text, "Draft 2")
        XCTAssertTrue(document.dirty)
        document.receive(text: "Draft 1", revision: "r2")
        XCTAssertFalse(document.hasConflict)
        XCTAssertEqual(document.text, "Draft 2")
        document.receive(text: "Draft 2", revision: "r3")
        XCTAssertFalse(document.dirty)
    }
    func testUnicodeDropboxHeaderRoundTripsEmojiAndAccents() throws {
        let path = "/PKMS/Psicologia 🧠/Perché.md"
        let header = try DropboxClient.headerJSON(["path": path])
        XCTAssertTrue(header.unicodeScalars.allSatisfy(\.isASCII))
        let decoded = try JSONSerialization.jsonObject(with: Data(header.utf8)) as? [String: String]
        XCTAssertEqual(decoded?["path"], path)
    }
    func testCorruptCacheIsReportedAndNeverSilentlyReset() async throws {
        let disk = try disk()
        let url = disk.root.appendingPathComponent("index.json")
        try Data("broken".utf8).write(to: url)
        let store = PKMSStore(api: PKMSDropboxFixture(), disk: disk)
        XCTAssertNotNil(store.storageError)
        await store.selectRoot("/replacement")
        await store.refreshConnection()
        store.retryLocalSave()
        XCTAssertNotNil(store.storageError)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "broken")
    }
    func testPinsAreCategoryScopedAndSurviveBackupWithoutPreviewDuplication() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let container = try LinkStore.container(at: root)
        let context = container.mainContext
        let first = try LinkStore.saveCollection(nil, name: "Studio", in: context)
        let second = try LinkStore.saveCollection(nil, name: "Lavoro", in: context)
        let receipt = try LinkStore.saveNote(title: "Indice", body: "Nota strutturata", urls: [], files: [], tags: [first.id, second.id], in: context)
        let note = try XCTUnwrap(context.fetch(FetchDescriptor<CapturedLink>()).first { $0.id == receipt.id })
        try LinkStore.setPinned(true, note: note, categoryID: first.id, in: context)
        XCTAssertEqual(note.pinnedCategoryIDs, [first.id])
        let backup = try BackupStore.snapshot(from: container)
        XCTAssertEqual(backup.items.first?.pinnedCategoryIDs, [first.id])
        try LinkStore.setTags([second.id], for: [note], in: context)
        XCTAssertTrue(note.pinnedCategoryIDs.isEmpty)
        try LinkStore.setTags([first.id, second.id], for: [note], in: context)
        XCTAssertTrue(note.pinnedCategoryIDs.isEmpty)
        let restoredRoot = root.appendingPathComponent("restore")
        let restored = try LinkStore.container(at: restoredRoot)
        _ = try BackupStore.restore(backup, into: restored)
        XCTAssertEqual(try restored.mainContext.fetch(FetchDescriptor<CapturedLink>()).first?.pinnedCategoryIDs, [first.id])
        let merged = try LinkStore.container(at: root.appendingPathComponent("merge"))
        let sameName = try LinkStore.saveCollection(nil, name: "Studio", in: merged.mainContext)
        _ = try BackupStore.restore(backup, into: merged)
        XCTAssertEqual(try merged.mainContext.fetch(FetchDescriptor<CapturedLink>()).first?.pinnedCategoryIDs, [sameName.id])
        _ = try BackupStore.snapshot(from: merged).validated()
    }
}

import Foundation
import Combine

@MainActor
final class PKMSStore: ObservableObject {
    @Published private(set) var index = PKMSIndex()
    @Published private(set) var documents: [String: PKMSDocument] = [:]
    @Published private(set) var syncing = false
    @Published private(set) var connected = false
    @Published var error: String?
    @Published private(set) var storageError: String?
    @Published private(set) var loading = Set<String>()
    private let api: any DropboxServing
    private var disk: PKMSDisk?
    private var loadFailed = false
    private var authorizationRejected = false
    private var allowsConnectionRefresh = true
    private var syncAgain = false
    private var scheduled: Task<Void, Never>?
    private(set) var accountID: String?

    init(api: any DropboxServing = DropboxClient.shared, disk: PKMSDisk? = nil, connected: Bool = false) {
        self.api = api
        self.connected = connected
        do {
            let storage = try disk ?? PKMSDisk()
            self.disk = storage
            let loadedIndex = try storage.loadIndex()
            let loadedDocuments = try storage.loadDocuments()
            index = loadedIndex
            documents = loadedDocuments
            accountID = loadedIndex.accountID ?? UserDefaults.standard.string(forKey: "pkms.accountID")
        } catch {
            loadFailed = true
            storageError = error.localizedDescription
        }
    }
    static func applicationStore() -> PKMSStore {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ui-test-in-memory") else { return PKMSStore() }
        do {
            let token = arguments.first { $0.hasPrefix("--ui-test-pkms=") }.map { String($0.dropFirst("--ui-test-pkms=".count)) } ?? UUID().uuidString
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("PKMS-UITest-" + token)
            let disk = try PKMSDisk(root: root)
            if arguments.contains(where: { $0.hasPrefix("--ui-test-pkms=") }), !FileManager.default.fileExists(atPath: root.appendingPathComponent("index.json").path) {
                let folder = DropboxEntry(tag: "folder", name: "Lavoro", id: "id:folder", pathLower: "/pkms/lavoro", pathDisplay: "/PKMS/Lavoro", rev: nil, size: nil)
                let note = DropboxEntry(tag: "file", name: "Contatti.md", id: "id:fixture", pathLower: "/pkms/lavoro/contatti.md", pathDisplay: "/PKMS/Lavoro/Contatti.md", rev: "r1", size: 30)
                try disk.saveIndex(PKMSIndex(root: "/pkms", entries: [folder, note]))
                try disk.save(PKMSDocument(id: note.identity, path: note.pathLower, text: "# Contatti\nAppunti iniziali", revision: "r1", syncedText: "# Contatti\nAppunti iniziali"))
            }
            let store = PKMSStore(disk: disk)
            store.allowsConnectionRefresh = false
            return store
        } catch { preconditionFailure("Cannot create isolated PKMS test workspace: \(error)") }
    }
    var pendingCount: Int { documents.values.filter { $0.dirty }.count }
    var conflictCount: Int { documents.values.filter { $0.hasConflict }.count }
    func refreshConnection() async {
        guard allowsConnectionRefresh, !authorizationRejected, !loadFailed else { return }
        do {
            connected = try await DropboxClient.shared.isConnected()
            if connected, let account = try await DropboxClient.shared.accountID() {
                if let accountID, accountID != account { connected = false; throw DropboxAuthError.differentAccount }
                try bindAccount(account)
            }
        }
        catch { self.error = error.localizedDescription }
    }
    func didConnect(account: String) async {
        do { try bindAccount(account) }
        catch { self.error = error.localizedDescription; return }
        authorizationRejected = false
        connected = true
        await sync()
    }
    func disconnect() async {
        guard !syncing else { return }
        do { try await DropboxClient.shared.disconnect(); connected = false }
        catch { self.error = error.localizedDescription }
    }
    func selectRoot(_ path: String) async {
        guard !syncing else { error = "Attendi la sincronizzazione in corso prima di cambiare cartella."; return }
        guard pendingCount == 0 else { error = "Sincronizza o risolvi le note modificate prima di cambiare cartella."; return }
        var next = PKMSIndex(); next.root = path; next.accountID = accountID
        do {
            try requireDisk().saveIndex(next)
            index = next
            await sync()
        } catch { self.error = error.localizedDescription }
    }
    func update(id: String, text: String) {
        guard var document = documents[id], document.text != text else { return }
        let previous = document
        document.text = text; document.modifiedAt = .now
        documents[id] = document
        do {
            let disk = try requireDisk()
            if !previous.dirty { try disk.preserve(previous) }
            try disk.save(document)
            storageError = nil
            scheduleSync()
        } catch { storageError = error.localizedDescription }
    }
    func retryLocalSave() {
        do {
            let disk = try requireDisk(allowRecovery: true)
            if loadFailed {
                let loadedIndex = try disk.loadIndex()
                let loadedDocuments = try disk.loadDocuments()
                index = loadedIndex; documents = loadedDocuments; loadFailed = false
            }
            for document in documents.values { try disk.save(document) }
            storageError = nil
            scheduleSync()
        } catch { storageError = error.localizedDescription }
    }
    func scheduleSync() {
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1.2)) } catch { return }
            guard !Task.isCancelled, let self else { return }
            await self.sync()
        }
    }
    func open(_ entry: DropboxEntry) async {
        guard !loading.contains(entry.identity) else { return }
        // Cached notes remain readable/editable even after disconnection.
        if let cached = documents[entry.identity], cached.revision == entry.rev { return }
        loading.insert(entry.identity)
        defer { loading.remove(entry.identity) }
        do { try await receive(entry) }
        catch { report(error) }
    }
    func sync() async {
        guard connected, index.root != nil, storageError == nil else { return }
        guard !syncing else { syncAgain = true; return }
        syncing = true
        defer {
            syncing = false
            if syncAgain { syncAgain = false; scheduleSync() }
        }
        do {
            let entries = try await refreshIndex()
            for entry in entries where !entry.isFolder {
                guard var cached = documents[entry.identity] else { continue }
                if cached.path != entry.pathLower { cached.path = entry.pathLower; try persist(cached) }
                if cached.revision != entry.rev || cached.remoteDeleted { try await receive(entry) }
                guard let draft = documents[entry.identity], draft.dirty, !draft.hasConflict else { continue }
                try await upload(draft)
            }
            for id in Array(documents.keys) {
                guard var document = documents[id], Self.inside(document.path, root: index.root ?? ""),
                      !entries.contains(where: { $0.identity == id }) else { continue }
                document.remoteDeleted = true
                try persist(document)
            }
            var next = index; next.lastSync = .now
            try requireDisk().saveIndex(next); index = next
            error = nil
        } catch { if !Task.isCancelled { report(error) } }
    }
    private func upload(_ draft: PKMSDocument) async throws {
        do {
            let metadata = try await api.upload(path: draft.id, revision: draft.revision, text: draft.text)
            guard let rev = metadata.rev, var latest = documents[draft.id] else { throw DropboxFailure.invalidResponse }
            latest.acknowledge(uploaded: draft.text, revision: rev)
            try persist(latest)
            if latest.dirty { syncAgain = true }
        } catch DropboxFailure.conflict {
            let remote = try await api.download(id: draft.id)
            guard let rev = remote.metadata.rev, var latest = documents[draft.id] else { throw DropboxFailure.invalidResponse }
            latest.receive(text: remote.text, revision: rev)
            try persist(latest)
        } catch DropboxFailure.remoteMissing {
            guard var latest = documents[draft.id] else { return }
            latest.remoteDeleted = true; try persist(latest)
        }
    }
    private func receive(_ entry: DropboxEntry) async throws {
        if let size = entry.size, size > 8 * 1024 * 1024 { throw DropboxFailure.tooLarge }
        let remote = try await api.download(id: entry.identity)
        guard let rev = remote.metadata.rev else { throw DropboxFailure.invalidResponse }
        var document = documents[entry.identity] ?? PKMSDocument(id: entry.identity, path: entry.pathLower,
            text: remote.text, revision: rev, syncedText: remote.text)
        document.path = remote.metadata.pathLower
        document.receive(text: remote.text, revision: rev)
        try persist(document)
    }
    /// Resolve against the exact remote revision displayed; another remote edit still causes a conflict.
    func resolve(id: String, keepLocal: Bool) {
        guard var document = documents[id], let remote = document.conflictText, let revision = document.conflictRevision else { return }
        do {
            try requireDisk().preserve(document)
            if !keepLocal { document.text = remote }
            document.syncedText = remote; document.revision = revision
            document.conflictText = nil; document.conflictRevision = nil
            try persist(document)
            scheduleSync()
        } catch { self.error = error.localizedDescription }
    }
    private func refreshIndex() async throws -> [DropboxEntry] {
        let root = index.root ?? ""
        var cursor = index.cursor
        var all = cursor == nil ? [] : index.entries
        var more = true
        while more {
            let page: DropboxListing
            do { page = try await api.list(path: root, recursive: true, cursor: cursor) }
            catch DropboxFailure.cursorReset {
                cursor = nil; all = []
                page = try await api.list(path: root, recursive: true, cursor: nil)
            }
            for entry in page.entries {
                if entry.tag == "deleted" {
                    all.removeAll { Self.inside($0.pathLower, root: entry.pathLower) }
                } else {
                    all.removeAll { $0.identity == entry.identity || $0.pathLower == entry.pathLower }
                    if entry.isFolder || entry.isMarkdown { all.append(entry) }
                }
            }
            cursor = page.cursor; more = page.hasMore
        }
        var next = index; next.cursor = cursor; next.entries = all
        try requireDisk().saveIndex(next); index = next
        return all
    }
    static func inside(_ path: String, root: String) -> Bool { root.isEmpty || path == root || path.hasPrefix(root + "/") }
    private func persist(_ document: PKMSDocument) throws {
        try requireDisk().save(document)
        documents[document.id] = document
    }
    private func report(_ error: Error) {
        if let failure = error as? DropboxFailure, failure == .unauthorized || failure == .notConnected {
            connected = false; authorizationRejected = true
        }
        self.error = error.localizedDescription
    }
    private func bindAccount(_ account: String) throws {
        if accountID == account, index.accountID == account { return }
        var next = index; next.accountID = account
        try requireDisk().saveIndex(next)
        index = next; accountID = account
        UserDefaults.standard.set(account, forKey: "pkms.accountID")
    }
    private func requireDisk(allowRecovery: Bool = false) throws -> PKMSDisk {
        guard !loadFailed || allowRecovery else { throw DropboxFailure.storage("Indice o documenti PKMS non leggibili. I file locali sono conservati e non verranno sostituiti con un archivio vuoto.") }
        guard let disk else { throw DropboxFailure.storage("Archivio PKMS non disponibile. Non verrà creato un archivio vuoto al suo posto.") }
        return disk
    }
    func recoveryVersions(id: String) throws -> [PKMSDocument] { try requireDisk().recoveryVersions(id: id) }
}

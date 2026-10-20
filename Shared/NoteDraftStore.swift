import Foundation

struct NoteDraft: Codable, Equatable, Sendable {
    var title: String
    var body: String
    var links: String
    var tags: Set<UUID>
    var files: [NoteFile]
    var place: NotePlace? = nil
    var placeEdited: Bool? = nil
}

/// Draft writes are serialized away from the UI. Closing a session invalidates
/// delayed writes so a successful save/discard cannot resurrect an old draft.
actor NoteDraftStore {
    static let shared: NoteDraftStore = {
        #if DEBUG
        let prefix = "--ui-test-drafts="
        if let value = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
           let id = UUID(uuidString: String(value.dropFirst(prefix.count))) {
            let root = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
            return NoteDraftStore(directory: root.appendingPathComponent("Bloom/DraftUITests/\(id.uuidString)", isDirectory: true))
        }
        #endif
        return NoteDraftStore()
    }()
    private let directory: URL?
    private var closedSessions = Set<UUID>()
    private var latestRevision: [UUID: Int] = [:]
    private var owners: [String: UUID] = [:]
    init(directory: URL? = nil) { self.directory = directory }

    private func location(_ key: UUID?) throws -> URL {
        let root: URL
        if let directory { root = directory }
        else {
            root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Bloom/Drafts", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent((key?.uuidString ?? "new") + ".json")
    }
    func load(_ key: UUID?, session: UUID? = nil) throws -> NoteDraft? {
        let url = try location(key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 40 * 1024 * 1024 else { throw ImportError.tooLarge }
        let value = try JSONDecoder().decode(NoteDraft.self, from: Data(contentsOf: url))
        guard value.place?.isValid ?? true else { throw ImportError.invalidFile }
        guard value.files.count <= 10, value.body.utf8.count + value.files.reduce(0, { $0 + $1.data.count }) <= AttachmentLoader.maximumBytes else { throw ImportError.tooLarge }
        if let session { owners[key?.uuidString ?? "new"] = session }
        return value
    }
    func save(_ draft: NoteDraft, key: UUID?, session: UUID, revision: Int = 0) throws {
        guard !Task.isCancelled, !closedSessions.contains(session), revision >= (latestRevision[session] ?? 0) else { return }
        let data = try JSONEncoder().encode(draft)
        guard data.count <= 40 * 1024 * 1024 else { throw ImportError.tooLarge }
        try data.write(to: location(key), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        latestRevision[session] = revision
        owners[key?.uuidString ?? "new"] = session
    }
    func saveAndClose(_ draft: NoteDraft, key: UUID?, session: UUID, revision: Int) throws {
        try Task.checkCancellation()
        guard !closedSessions.contains(session) else { throw CancellationError() }
        try save(draft, key: key, session: session, revision: max(revision, latestRevision[session] ?? 0))
        closedSessions.insert(session)
    }
    func clear(_ key: UUID?, session: UUID) throws {
        closedSessions.insert(session)
        if let owner = owners[key?.uuidString ?? "new"], owner != session { return }
        let url = try location(key)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        owners.removeValue(forKey: key?.uuidString ?? "new")
    }
}

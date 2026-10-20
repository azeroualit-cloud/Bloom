import Foundation

/// Separate from the media archive: original Markdown, recovery versions and Dropbox index.
struct PKMSDisk {
    let root: URL
    init(root: URL = URL.applicationSupportDirectory.appendingPathComponent("PKMS", isDirectory: true)) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    func loadIndex() throws -> PKMSIndex {
        let url = root.appendingPathComponent("index.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return PKMSIndex() }
        return try JSONDecoder().decode(PKMSIndex.self, from: Data(contentsOf: url))
    }
    func saveIndex(_ index: PKMSIndex) throws { try write(index, to: root.appendingPathComponent("index.json")) }
    func loadDocuments() throws -> [String: PKMSDocument] {
        var result: [String: PKMSDocument] = [:]
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) where url.lastPathComponent.hasPrefix("doc-") {
            let document = try JSONDecoder().decode(PKMSDocument.self, from: Data(contentsOf: url))
            result[document.id] = document
        }
        return result
    }
    func save(_ document: PKMSDocument) throws { try write(document, to: documentURL(document.id)) }
    func preserve(_ document: PKMSDocument) throws {
        let history = root.appendingPathComponent("Recovery", isDirectory: true)
        try FileManager.default.createDirectory(at: history, withIntermediateDirectories: true)
        try write(document, to: history.appendingPathComponent("\(UUID().uuidString).json"))
    }
    func recoveryVersions(id: String) throws -> [PKMSDocument] {
        let directory = root.appendingPathComponent("Recovery", isDirectory: true)
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { try JSONDecoder().decode(PKMSDocument.self, from: Data(contentsOf: $0)) }
            .filter { $0.id == id }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }
    private func documentURL(_ id: String) -> URL {
        root.appendingPathComponent("doc-" + Data(id.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_") + ".json")
    }
    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

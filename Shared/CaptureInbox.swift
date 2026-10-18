import Foundation

struct PendingCapture: Codable {
    let id: UUID
    let url: URL
    let capturedAt: Date
}

struct CaptureInbox {
    let directory: URL

    static func sharedRoot() throws -> URL {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "BloomAppGroup") as? String,
              let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { throw CaptureError.appGroupUnavailable }
        return root
    }

    init(root: URL) throws {
        directory = root.appendingPathComponent("CaptureInbox", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(_ url: URL) throws {
        let capture = PendingCapture(id: UUID(), url: try LinkValidation.validate(url), capturedAt: .now)
        let destination = directory.appendingPathComponent(capture.id.uuidString).appendingPathExtension("json")
        try JSONEncoder().encode(capture).write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func pendingFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func read(_ file: URL) throws -> PendingCapture {
        try JSONDecoder().decode(PendingCapture.self, from: Data(contentsOf: file))
    }

    func remove(_ file: URL) throws { try FileManager.default.removeItem(at: file) }
}

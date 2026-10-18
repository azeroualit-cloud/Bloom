import Foundation
import SwiftData

/// Only Bloom writes the SwiftData database. The extension writes atomic inbox files.
/// This avoids concurrent SwiftData writers and keeps capture independent of app startup.
@MainActor
enum LinkStore {
    static func container(at directory: URL) throws -> ModelContainer {
        let schema = Schema([CapturedLink.self])
        let configuration = ModelConfiguration(
            schema: schema, url: directory.appendingPathComponent("Bloom.store"),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func importInbox(_ inbox: CaptureInbox, into context: ModelContext) throws {
        for file in try inbox.pendingFiles() {
            let capture = try inbox.read(file)
            let id = capture.id
            let request = FetchDescriptor<CapturedLink>(predicate: #Predicate { $0.id == id })
            if try context.fetch(request).isEmpty {
                context.insert(CapturedLink(url: try LinkValidation.validate(capture.url),
                                            id: id, capturedAt: capture.capturedAt))
                do { try context.save() }
                catch { context.rollback(); throw error }
            }
            // Delete only after a successful save. A retry recognizes the same capture UUID.
            try inbox.remove(file)
        }
    }
}

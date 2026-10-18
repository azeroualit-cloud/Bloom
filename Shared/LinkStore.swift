import Foundation
import SwiftData

@MainActor
enum LinkStore {
    static func container(at directory: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = Schema([CapturedLink.self])
        let configuration = ModelConfiguration(
            schema: schema, url: directory.appendingPathComponent("Bloom.store"),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Returns false for an exact URL already present. All entry points use this path.
    @discardableResult
    static func capture(_ url: URL, into context: ModelContext) throws -> Bool {
        let valid = try LinkValidation.validate(url)
        let value = valid.absoluteString
        let request = FetchDescriptor<CapturedLink>(predicate: #Predicate { $0.urlString == value })
        guard try context.fetch(request).isEmpty else { return false }
        context.insert(CapturedLink(url: valid))
        do { try context.save() }
        catch { context.rollback(); throw error }
        return true
    }
}

@MainActor
enum LocalLibrary {
    private static var cached: ModelContainer?

    static func open() throws -> ModelContainer {
        if let cached { return cached }
        let root = try FileManager.default.url(for: .applicationSupportDirectory,
                                              in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Bloom", isDirectory: true)
        let container = try LinkStore.container(at: root)
        cached = container
        return container
    }
}

import Foundation
import LinkPresentation
import UIKit
import CryptoKit

/// Rebuildable, bounded disk cache. Primary posters remain in the library store.
actor SecondaryPreviewCache {
    static let shared = SecondaryPreviewCache()
    private var pending: [String: Task<Data?, Never>] = [:]
    private var attempted: [String: Date] = [:]
    private let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("BloomPosters", isDirectory: true)
    func image(for url: URL) async -> Data? {
        let key = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        let path = directory.appendingPathComponent(key)
        if let data = try? Data(contentsOf: path) { return data }
        if let task = pending[key] { return await task.value }
        if let date = attempted[key], Date().timeIntervalSince(date) < 86_400 { return nil }
        attempted[key] = .now
        let task = Task { await Self.fetch(url) }
        pending[key] = task
        let data = await task.value
        pending[key] = nil
        if let data {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: path, options: .atomic)
            prune()
        }
        return data
    }
    private func prune() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? []
        let files = urls.compactMap { url -> (URL, Date, Int)? in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, values.fileSize ?? 0)
        }.sorted { $0.1 < $1.1 }
        var bytes = files.reduce(0) { $0 + $1.2 }
        for file in files where bytes > 32 * 1024 * 1024 { try? FileManager.default.removeItem(at: file.0); bytes -= file.2 }
        if attempted.count > 1000 { attempted = attempted.filter { Date().timeIntervalSince($0.value) < 86_400 } }
    }
    @MainActor private static func fetch(_ url: URL) async -> Data? {
        let provider = LPMetadataProvider(); provider.timeout = 12; provider.shouldFetchSubresources = true
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            guard let source = metadata.imageProvider else { return nil }
            let image: UIImage = try await withCheckedThrowingContinuation { continuation in
                source.loadObject(ofClass: UIImage.self) { object, error in
                    if let image = object as? UIImage { continuation.resume(returning: image) }
                    else { continuation.resume(throwing: error ?? ImportError.unreadableImage) }
                }
            }
            return LinkPreviewController.compressed(image)
        } catch { return nil }
    }
}

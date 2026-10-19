import Foundation
import SwiftData
import LinkPresentation
import Observation

@MainActor
@Observable
final class LinkTitleController {
    typealias Fetcher = @MainActor (URL) async throws -> String?
    var isLoading = false
    var message: String?
    private var task: Task<Void, Never>?
    private var requestID = UUID()

    func cancel() {
        requestID = UUID()
        task?.cancel()
        task = nil
        isLoading = false
    }

    func start(_ items: [CapturedLink], in context: ModelContext, fetch: Fetcher? = nil) {
        cancel()
        let candidates = items.filter { $0.kind == .link && ($0.title?.isEmpty ?? true) }
        guard candidates.count <= 10 else {
            message = "Seleziona al massimo 10 link senza titolo per operazione."
            return
        }
        guard !candidates.isEmpty else { message = "I contenuti selezionati hanno già un titolo o non sono link."; return }
        let id = requestID
        let fetcher = fetch ?? { url in try await Self.fetchTitle(url) }
        isLoading = true
        message = nil
        task = Task {
            var updated = 0
            var unavailable = 0
            defer { if id == requestID { isLoading = false; task = nil } }
            for item in candidates {
                do {
                    try Task.checkCancellation()
                    guard let url = URL(string: item.urlString) else { unavailable += 1; continue }
                    let title = try await fetcher(url)
                    try Task.checkCancellation()
                    guard id == requestID else { return }
                    if let title, try LinkStore.fillMissingTitle(title, for: item, in: context) { updated += 1 }
                    else { unavailable += 1 }
                } catch is CancellationError { return }
                catch { unavailable += 1 }
            }
            if id == requestID { message = "Titoli aggiornati: \(updated). Non disponibili o già modificati: \(unavailable)." }
        }
    }

    private static func fetchTitle(_ url: URL) async throws -> String? {
        _ = try LinkValidation.validate(url)
        let provider = LPMetadataProvider()
        provider.timeout = 10
        provider.shouldFetchSubresources = false
        return try await withTaskCancellationHandler {
            try await provider.startFetchingMetadata(for: url).title
        } onCancel: {
            Task { @MainActor in provider.cancel() }
        }
    }
}

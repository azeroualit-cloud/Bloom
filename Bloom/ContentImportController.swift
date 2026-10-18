import Foundation
import SwiftData
import PhotosUI
import CoreTransferable
import Observation

struct ImportedPhoto: Transferable, Sendable {
    let payload: AttachmentPayload
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            ImportedPhoto(payload: try AttachmentLoader.read(received.file))
        }
    }
}

@MainActor
@Observable
final class ContentImportController {
    var isImporting = false
    var message: String?
    var completionID = UUID()
    var error: String?
    var canRetry: Bool { pending != nil }
    private var pending: AttachmentPayload?
    private var task: Task<Void, Never>?
    private var requestID = UUID()

    func importFile(_ url: URL, into context: ModelContext) {
        load(into: context) {
            try await Task.detached(priority: .userInitiated) {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                return try AttachmentLoader.read(url)
            }.value
        }
    }

    func importPhoto(_ item: PhotosPickerItem, into context: ModelContext) {
        load(into: context) {
            guard let photo = try await item.loadTransferable(type: ImportedPhoto.self) else {
                throw ImportError.missingData
            }
            return photo.payload
        }
    }

    func cancel() {
        requestID = UUID()
        task?.cancel()
        task = nil
        pending = nil
        isImporting = false
    }

    func retry(into context: ModelContext) {
        guard let pending else { return }
        do {
            let inserted = try LinkStore.captureAttachment(pending, into: context)
            message = inserted ? "Contenuto importato" : "Contenuto già presente. Controlla anche Archivio."
            self.pending = nil
            error = nil
            completionID = UUID()
        } catch { self.error = error.localizedDescription }
    }

    private func load(into context: ModelContext,
                      operation: @escaping @Sendable () async throws -> AttachmentPayload) {
        cancel()
        let id = requestID
        error = nil
        message = nil
        isImporting = true
        task = Task {
            defer {
                if requestID == id { isImporting = false; task = nil }
            }
            do {
                let payload = try await operation()
                try Task.checkCancellation()
                guard requestID == id else { return }
                pending = payload
                retry(into: context)
            } catch is CancellationError { }
            catch {
                if requestID == id { self.error = error.localizedDescription }
            }
        }
    }
}

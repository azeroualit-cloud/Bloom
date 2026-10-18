import SwiftUI
import QuickLook
import ImageIO
import UIKit

@MainActor
struct AttachmentView: View {
    let item: CapturedLink
    @State private var thumbnail: UIImage?
    @State private var thumbnailFinished = false
    @State private var error: String?
    @State private var loading = false
    @State private var previewURL: URL?
    @State private var previewDirectory: URL?
    @State private var exportURL: URL?

    var body: some View {
        Section(item.kind.label) {
            if item.kind == .image {
                if let thumbnail {
                    Image(uiImage: thumbnail).resizable().scaledToFit()
                        .accessibilityLabel(item.displayTitle)
                } else if !thumbnailFinished { ProgressView("Caricamento immagine…") }
                else { Label("Anteprima immagine non disponibile", systemImage: "photo.badge.exclamationmark") }
            }
            Text(item.fileName ?? item.kind.label).textSelection(.enabled)
            if let count = item.attachmentByteCount {
                Text(ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file))
                    .foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red) }
            if let exportURL { ShareLink("Condividi file", item: exportURL) }
            if loading { ProgressView("Preparazione anteprima…") }
            Button("Apri anteprima", systemImage: "doc.viewfinder", action: preview)
                .disabled(loading)
        }
        .task(id: item.id) { await loadThumbnail() }
        .quickLookPreview($previewURL)
        .onChange(of: previewURL) { old, new in
            if old != nil && new == nil, let directory = previewDirectory {
                try? FileManager.default.removeItem(at: directory)
                previewDirectory = nil
                exportURL = nil
            }
        }
    }

    private func loadThumbnail() async {
        guard item.kind == .image else { return }
        defer { thumbnailFinished = true }
        guard let data = item.attachmentData else { error = ImportError.missingData.localizedDescription; return }
        let image = await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2048
                  ] as CFDictionary) else { return Optional<UIImage>.none }
            return UIImage(cgImage: cgImage)
        }.value
        guard !Task.isCancelled else { return }
        thumbnail = image
        if image == nil { error = ImportError.unreadableImage.localizedDescription }
    }

    private func preview() {
        guard let data = item.attachmentData else { error = ImportError.missingData.localizedDescription; return }
        let name = item.fileName ?? "contenuto"
        if let directory = previewDirectory {
            try? FileManager.default.removeItem(at: directory)
            previewDirectory = nil
            exportURL = nil
        }
        loading = true
        error = nil
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let directory = FileManager.default.temporaryDirectory
                        .appendingPathComponent("BloomPreview-" + UUID().uuidString, isDirectory: true)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let safeName = String(URL(fileURLWithPath: name).lastPathComponent.prefix(180))
                    let url = directory.appendingPathComponent(safeName.isEmpty ? "contenuto" : safeName)
                    do { try data.write(to: url, options: .atomic) }
                    catch { try? FileManager.default.removeItem(at: directory); throw error }
                    return (directory, url)
                }.value
                previewDirectory = result.0
                exportURL = result.1
                if QLPreviewController.canPreview(result.1 as NSURL) {
                    previewURL = result.1
                } else {
                    error = "Questo formato non supporta l’anteprima di sistema. Il file è conservato in Bloom."
                }
            } catch { self.error = error.localizedDescription }
            loading = false
        }
    }
}

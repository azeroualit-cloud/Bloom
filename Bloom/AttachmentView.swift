import SwiftUI
import QuickLook
import UIKit

@MainActor
struct AttachmentView: View {
    let item: CapturedLink
    @State private var reader: TextDocument?
    @State private var error: String?
    @State private var loading = false
    @State private var previewURL: URL?
    @State private var previewDirectory: URL?
    @State private var exportURL: URL?

    var body: some View {
        Section(item.kind.label) {
            if item.kind == .image {
                NavigationLink { ImageContentView(item: item) } label: {
                    AttachmentThumbnail(item: item, maximumPixelSize: 768).frame(maxHeight: 220)
                }
            }
            Text(item.fileName ?? item.kind.label).textSelection(.enabled)
            if let count = item.attachmentByteCount {
                Text(ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file))
                    .foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red) }
            if let exportURL { ShareLink("Condividi file", item: exportURL) }
            if loading { ProgressView("Preparazione anteprima…") }
            if item.kind != .image {
                Button("Apri contenuto", systemImage: "doc.viewfinder", action: preview)
                    .disabled(loading)
            }
        }
        .sheet(item: $reader) { document in
            NavigationStack {
                ScrollView {
                    Text(document.text).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding()
                }
                .navigationTitle(document.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { reader = nil } } }
            }
        }
        .quickLookPreview($previewURL)
        .onChange(of: previewURL) { old, new in
            if old != nil && new == nil, let directory = previewDirectory {
                try? FileManager.default.removeItem(at: directory)
                previewDirectory = nil
                exportURL = nil
            }
        }
    }

    private func preview() {
        guard let data = item.attachmentData else { error = ImportError.missingData.localizedDescription; return }
        let name = item.fileName ?? "contenuto"
        if let text = DocumentText.decode(data, name: name, type: item.contentType) {
            reader = TextDocument(title: name, text: text)
            return
        }
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

private struct TextDocument: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}

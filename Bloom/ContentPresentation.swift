import SwiftUI
import SwiftData
import LinkPresentation
import ImageIO
import UIKit
import Observation

@MainActor
@Observable
final class LinkPreviewController {
    static let shared = LinkPreviewController()
    var isLoading = false
    var message: String?
    private var queued = Set<UUID>()
    private var tail: Task<Void, Never>?

    func prepare(for link: CapturedLink, in context: ModelContext) {
        guard link.previewImageData == nil, let url = link.allLinks.first,
              !queued.contains(link.id),
              link.previewAttemptedAt.map({ Date().timeIntervalSince($0) >= 86_400 }) ?? true else { return }
        queued.insert(link.id)
        let previous = tail
        tail = Task {
            await previous?.value
            isLoading = true
            defer { isLoading = false; queued.remove(link.id) }
            do {
                link.previewAttemptedAt = .now
                try context.save()
                let provider = LPMetadataProvider()
                provider.timeout = 12
                provider.shouldFetchSubresources = true
                let metadata = try await provider.startFetchingMetadata(for: url)
                guard let imageProvider = metadata.imageProvider else {
                    return
                }
                let image = try await loadImage(from: imageProvider)
                guard let data = Self.compressed(image) else {
                    message = "L’anteprima del sito non è utilizzabile."
                    return
                }
                guard link.allLinks.first == url else { return }
                try LinkStore.storePreview(data, sourceURL: url, for: link, in: context)
            } catch is CancellationError { }
            catch { message = "Anteprima non disponibile. Puoi continuare nel browser." }
        }
    }

    private func loadImage(from provider: NSItemProvider) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, error in
                if let image = object as? UIImage { continuation.resume(returning: image) }
                else { continuation.resume(throwing: error ?? ImportError.unreadableImage) }
            }
        }
    }

    private static func compressed(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1600 / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.82)
    }
}

struct CachedPreviewImage: View {
    let data: Data?
    let label: String
    let maxPixel: Int
    @State private var image: UIImage?
    @State private var decodingFinished = false

    init(data: Data?, label: String, maxPixel: Int = 2048) {
        self.data = data
        self.label = label
        self.maxPixel = maxPixel
    }

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit().accessibilityLabel(label) }
            else if data != nil && !decodingFinished { ProgressView("Preparazione immagine…") }
            else { ContentUnavailableView("Immagine non disponibile", systemImage: "photo") }
        }
        .task(id: data) {
            decodingFinished = false
            let decoded = await Self.decode(data, maximumPixel: maxPixel)
            guard !Task.isCancelled else { return }
            image = decoded; decodingFinished = true
        }
    }

    static func decode(_ data: Data?, maximumPixel: Int) async -> UIImage? {
        guard let data else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maximumPixel
                  ] as CFDictionary) else { return nil }
            return UIImage(cgImage: image)
        }.value
    }
}

struct ImageContentView: View {
    let item: CapturedLink
    @State private var showingDetails = false
    @State private var cleanEdges = true
    @State private var framing = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()
                FramedImage(data: item.attachmentData, framing: item.imageFraming, zoomable: true)
                    .padding(cleanEdges ? 12 : 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .navigationTitle(item.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Dettagli") { showingDetails = true } }
            ToolbarItem(placement: .topBarTrailing) { Button("Inquadratura") { framing = true } }
            ToolbarItem(placement: .secondaryAction) {
                Toggle(cleanEdges ? "Sfondo pulito" : "A pieno schermo", isOn: $cleanEdges)
            }
        }
        .sheet(isPresented: $showingDetails) {
            NavigationStack { LinkDetailView(link: item).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fine") { showingDetails = false } } } }
        }
        .sheet(isPresented: $framing) { ImageFramingEditor(item: item) }
    }
}

enum TextContentSource { case capturedText, attachment }

@MainActor
struct TextContentView: View {
    @Environment(\.modelContext) private var context
    let item: CapturedLink
    let source: TextContentSource
    let originalText: String
    @State private var showingSource = false
    @State private var editing = false
    @State private var draft = ""
    @State private var error: String?
    @State private var showingDetails = false

    init(item: CapturedLink, source: TextContentSource = .capturedText, originalText: String? = nil) {
        self.item = item
        self.source = source
        self.originalText = originalText ?? item.textContent ?? ""
        _draft = State(initialValue: originalText ?? item.textContent ?? "")
    }

    var body: some View {
        Group {
            if editing { editor }
            else { reader }
        }
        .navigationTitle(item.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $showingDetails) {
            NavigationStack { LinkDetailView(link: item).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fine") { showingDetails = false } } } }
        }
        .alert("Modifica non riuscita", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(error ?? "") }
    }

    private var reader: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if showingSource {
                    Text(currentText).font(.body.monospaced()).textSelection(.enabled)
                } else {
                    MarkdownDocumentView(text: currentText)
                }
            }.frame(maxWidth: 720, alignment: .leading).padding(20)
        }
    }

    private var editor: some View {
        TextEditor(text: $draft)
            .font(.body.monospaced())
            .padding(12)
            .accessibilityLabel("Testo modificabile")
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if editing { Button("Salva", action: save).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            else { Button("Dettagli") { showingDetails = true } }
        }
        ToolbarItem(placement: .secondaryAction) {
            if editing { Button("Annulla") { editing = false; draft = currentText } }
            else { Button(showingSource ? "Lettura" : "Sorgente") { showingSource.toggle() } }
        }
        ToolbarItem(placement: .secondaryAction) {
            if !editing { Button("Modifica") { draft = currentText; editing = true } }
        }
    }

    private func save() {
        do {
            switch source {
            case .capturedText: try LinkStore.updateTextContent(draft, for: item, in: context)
            case .attachment: try LinkStore.updateDocumentText(draft, for: item, in: context)
            }
            editing = false
        } catch { self.error = error.localizedDescription }
    }
    private var currentText: String {
        switch source {
        case .capturedText: return item.textContent ?? ""
        case .attachment:
            return item.attachmentData.flatMap { DocumentText.decode($0, name: item.fileName ?? "contenuto", type: item.contentType) } ?? originalText
        }
    }
}

private struct MarkdownText: View {
    let text: String
    var body: some View {
        if let rich = try? AttributedString(markdown: text) {
            Text(rich).textSelection(.enabled).accessibilityIdentifier("detail-content-text")
        } else {
            Text(text).textSelection(.enabled).accessibilityIdentifier("detail-content-text")
        }
    }
}

struct SocialPreviewCard: View {
    let item: CapturedLink
    let isLoading: Bool
    let message: String?
    var body: some View {
        if item.previewImageData != nil || isLoading || message != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let data = item.previewImageData {
                    CachedPreviewImage(data: data, label: item.displayTitle, maxPixel: 1200)
                        .frame(maxHeight: 220).clipShape(RoundedRectangle(cornerRadius: 14))
                } else if isLoading { ProgressView("Preparazione anteprima…") }
                if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
            }.padding(12).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

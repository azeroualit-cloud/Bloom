import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers
import QuickLook

struct MarkdownExcerpt: View {
    let text: String
    var font: Font = .subheadline
    var body: some View {
        let excerpt = String(text.prefix(350))
        Text((try? AttributedString(markdown: excerpt, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(excerpt))
            .font(font).foregroundStyle(Color.bloomText)
    }
}

@MainActor
struct NoteLinkButton: View {
    let item: CapturedLink
    let url: URL
    var onOpenNote: (() -> Void)? = nil
    @State private var fallback = false
    @State private var opening = false
    @State private var secondaryPoster: Data?
    private var poster: Data? { item.previewSourceURL == url.absoluteString ? item.previewImageData : secondaryPoster }
    private var isVideo: Bool { SocialLink.isVideo(url) }
    var body: some View {
        Button(action: open) {
            GeometryReader { proxy in
                Color.bloomSurface.overlay {
                    ZStack {
                        if let data = poster {
                            CachedPreviewImage(data: data, label: item.displayTitle, maxPixel: 1000, contentMode: .fill)
                                .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: isVideo ? "video" : "link").font(.title2)
                                Text(url.host ?? "Link").font(.subheadline).lineLimit(1)
                            }
                        }
                        if isVideo && poster == nil && onOpenNote == nil {
                            Image(systemName: "play.fill").font(.title2).padding(12).background(.black.opacity(0.65), in: Circle()).foregroundStyle(.white)
                        }
                        if opening { ProgressView().padding().background(.regularMaterial, in: Capsule()) }
                    }.frame(width: proxy.size.width, height: proxy.size.height).clipped()
                }.contentShape(Rectangle())
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(opening)
            .accessibilityLabel(onOpenNote != nil ? "Apri nota: \(item.displayTitle)" : SocialLink.instagramPostURL(url) != nil ? "Visualizza post Instagram in Bloom" : isVideo ? "Apri video in \(url.host ?? "app")" : "Apri \(url.host ?? "link")")
            .accessibilityIdentifier("note-link-open")
            .task(id: url) {
                guard item.allLinks.first != url else { return }
                let data = await SecondaryPreviewCache.shared.image(for: url)
                guard !Task.isCancelled else { return }
                secondaryPoster = data
            }
            .navigationDestination(isPresented: $fallback) { WebContentView(item: item, url: url) }
    }
    private func open() {
        guard item.modelContext != nil, !item.isDeleted else { return }
        if let onOpenNote { onOpenNote(); return }
        guard SocialLink.opensInApp(url) else { fallback = true; return }
        opening = true
        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { success in
            Task { @MainActor in opening = false; if !success { fallback = true } }
        }
    }
}

@MainActor
struct NoteDetailView: View {
    let item: CapturedLink
    @State private var editing = false
    @State private var details = false
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if item.carouselPageCount > (item.noteBody.isEmpty ? 0 : 1) {
                    NoteCarousel(item: item, showsBody: false)
                }
                NoteOrganizationControls(item: item)
                Text(item.displayTitle).font(.title2.bold()).foregroundStyle(Color.bloomText).textSelection(.enabled).accessibilityIdentifier("note-detail-title")
                if !item.noteBody.isEmpty {
                    MarkdownDocumentView(text: item.noteBody).accessibilityIdentifier("note-detail-body")
                }
            }.padding(20).frame(maxWidth: 740, alignment: .leading).frame(maxWidth: .infinity)
        }
        .bloomCanvas().navigationTitle(item.displayTitle).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Modifica") { editing = true } }
            ToolbarItem(placement: .topBarTrailing) { Button("Dettagli") { details = true } }
        }
        .sheet(isPresented: $editing) { NoteComposer(item: item) { _ in } }
        .sheet(isPresented: $details) {
            NavigationStack { LinkDetailView(link: item).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fine") { details = false } } } }
        }
        .task(id: item.allLinks.first) {
            if let context = item.modelContext { LinkPreviewController.shared.prepare(for: item, in: context) }
        }
    }
}

struct NoteFileView: View {
    let file: NoteFile
    var autoPreview = false
    @State private var staged: URL?
    @State private var directory: URL?
    @State private var error: String?
    @State private var preview: URL?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if UTType(file.type)?.conforms(to: .image) == true {
                    CachedPreviewImage(data: file.data, label: file.name, maxPixel: 4096)
                } else if let text = DocumentText.decode(file.data, name: file.name, type: file.type) {
                    MarkdownDocumentView(text: text)
                }
                if let staged {
                    Button("Anteprima di sistema") { preview = staged }
                    ShareLink("Condividi file", item: staged)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.padding()
        }.bloomCanvas().navigationTitle(file.name).navigationBarTitleDisplayMode(.inline)
            .quickLookPreview($preview)
            .task {
                guard staged == nil else { return }
                do {
                    let file = file
                    let result = try await Task.detached {
                        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("BloomNote-\(UUID().uuidString)", isDirectory: true)
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        let url = directory.appendingPathComponent(URL(fileURLWithPath: file.name).lastPathComponent)
                        do { try file.data.write(to: url, options: .atomic) }
                        catch { try? FileManager.default.removeItem(at: directory); throw error }
                        return (directory, url)
                    }.value
                    if Task.isCancelled { try? FileManager.default.removeItem(at: result.0) }
                    else {
                        directory = result.0; staged = result.1
                        if autoPreview && QLPreviewController.canPreview(result.1 as NSURL) { preview = result.1 }
                    }
                } catch { self.error = error.localizedDescription }
            }
            .onDisappear {
                guard preview == nil else { return }
                if let directory { try? FileManager.default.removeItem(at: directory) }
                directory = nil; staged = nil
            }
    }
}

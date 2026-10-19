import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers
import QuickLook

struct NoteCard: View {
    let item: CapturedLink
    let tags: [LinkCollection]
    let openNote: () -> Void
    @State private var editingTags = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let url = item.allLinks.first {
                NoteLinkButton(item: item, url: url)
            } else if item.kind == .image {
                NavigationLink { PrimaryContentView(item: item) } label: {
                    AttachmentThumbnail(item: item, maximumPixelSize: 768).frame(maxWidth: .infinity).frame(height: 220)
                }.buttonStyle(.plain).accessibilityIdentifier("note-primary-open")
            } else if item.kind == .file {
                NavigationLink { PrimaryContentView(item: item) } label: {
                    Label(item.fileName ?? "Documento", systemImage: "doc.text").frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                }.buttonStyle(.plain).accessibilityIdentifier("note-primary-open")
            }
            Button(action: openNote) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.displayTitle).font(.headline).foregroundStyle(.primary).lineLimit(2)
                    if !item.noteBody.isEmpty { MarkdownExcerpt(text: item.noteBody).lineLimit(4).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("note-open-\(item.id)")
            HStack {
                let assigned = item.tagIDs
                let names = tags.filter { assigned.contains($0.id) }.map(\.name)
                Button { editingTags = true } label: {
                    Text(names.isEmpty ? "Da specificare" : names.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(minHeight: 44)
                }.buttonStyle(.plain).accessibilityLabel("Modifica tag").accessibilityIdentifier("quick-tags-\(item.id)")
                Spacer()
                let count = item.allLinks.count + (item.noteFileCount ?? 0) + ((item.kind == .image || item.kind == .file) ? 1 : 0)
                if count > 0 {
                    Label("\(count)", systemImage: "paperclip").font(.caption)
                }
                Menu {
                    Button("Apri nota", action: openNote)
                    if !item.allLinks.isEmpty {
                        Button("Aggiorna anteprima", systemImage: "arrow.clockwise") { LinkPreviewController.shared.prepare(for: item, in: previewContext, force: true) }
                    }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Azioni nota")
            }
        }.padding(16).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            .task(id: item.allLinks.first) { LinkPreviewController.shared.prepare(for: item, in: previewContext) }
            .sheet(isPresented: $editingTags) { NoteTagEditor(item: item) }
    }
    @Environment(\.modelContext) private var previewContext
}

struct MarkdownExcerpt: View {
    let text: String
    var body: some View {
        let excerpt = String(text.prefix(350))
        Text((try? AttributedString(markdown: excerpt, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(excerpt))
            .font(.subheadline)
    }
}

@MainActor
struct NoteLinkButton: View {
    private static let previewHeight: CGFloat = 200
    let item: CapturedLink
    let url: URL
    @State private var fallback = false
    @State private var opening = false
    private var isVideo: Bool { SocialLink.isVideo(url) }
    var body: some View {
        Button(action: open) {
            ZStack {
                if let data = item.previewImageData, item.previewSourceURL == url.absoluteString {
                    CachedPreviewImage(data: data, label: item.displayTitle, maxPixel: 1000)
                        .frame(maxWidth: .infinity, maxHeight: Self.previewHeight)
                } else {
                    RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.08)).frame(height: Self.previewHeight)
                    VStack(spacing: 8) {
                        Image(systemName: isVideo ? "video" : "link").font(.title2)
                        Text(url.host ?? "Link").font(.subheadline).lineLimit(1)
                    }
                }
                if isVideo { Image(systemName: "play.circle.fill").font(.largeTitle).symbolRenderingMode(.palette).foregroundStyle(.white, .black.opacity(0.6)) }
                if opening { ProgressView().padding().background(.regularMaterial, in: Capsule()) }
            }.frame(maxWidth: .infinity).frame(height: Self.previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain).disabled(opening)
            .accessibilityLabel(isVideo ? "Apri video in \(url.host ?? "app")" : "Apri \(url.host ?? "link")")
            .accessibilityIdentifier("note-link-open")
            .navigationDestination(isPresented: $fallback) { WebContentView(item: item, url: url) }
    }
    private func open() {
        guard isVideo else { fallback = true; return }
        opening = true
        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { success in
            Task { @MainActor in opening = false; if !success { fallback = true } }
        }
    }
}

@MainActor
struct NoteDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LinkCollection.name) private var tags: [LinkCollection]
    let item: CapturedLink
    @State private var editing = false
    @State private var details = false
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if !item.noteBody.isEmpty { MarkdownDocumentView(text: item.noteBody) }
                ForEach(item.allLinks, id: \.absoluteString) { url in NoteLinkButton(item: item, url: url) }
                if item.kind == .image || item.kind == .file {
                    NavigationLink { PrimaryContentView(item: item) } label: {
                        if item.kind == .image { AttachmentThumbnail(item: item, maximumPixelSize: 1400).frame(maxHeight: 420) }
                        else { Label(item.fileName ?? "Apri documento", systemImage: "doc.text") }
                    }
                }
                ForEach(item.noteFiles) { file in
                    NavigationLink { NoteFileView(file: file) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            if UTType(file.type)?.conforms(to: .image) == true {
                                CachedPreviewImage(data: file.data, label: file.name).frame(maxHeight: 360)
                            }
                            Label(file.name, systemImage: "paperclip").font(.subheadline)
                        }
                    }
                }
                Text(tagNames).font(.caption).foregroundStyle(.secondary)
            }.padding(20).frame(maxWidth: 740, alignment: .leading).frame(maxWidth: .infinity)
        }
        .navigationTitle(item.displayTitle).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Modifica") { editing = true } }
            ToolbarItem(placement: .topBarTrailing) { Button("Dettagli") { details = true } }
        }
        .sheet(isPresented: $editing) { NoteComposer(item: item) { _ in } }
        .sheet(isPresented: $details) {
            NavigationStack { LinkDetailView(link: item).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fine") { details = false } } } }
        }
        .task(id: item.allLinks.first) { LinkPreviewController.shared.prepare(for: item, in: context) }
    }
    private var tagNames: String {
        let names = tags.filter { item.tagIDs.contains($0.id) }.map(\.name)
        return names.isEmpty ? "Da specificare" : names.joined(separator: " · ")
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
        }.navigationTitle(file.name).navigationBarTitleDisplayMode(.inline)
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

struct MarkdownDocumentView: View {
    let text: String
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(Array(MarkdownBlock.parse(text).enumerated()), id: \.offset) { _, block in
                blockView(block).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.accessibilityIdentifier("detail-content-text")
    }
    @ViewBuilder private func blockView(_ block: MarkdownBlock) -> some View {
        let rich = (try? AttributedString(markdown: block.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(block.text)
        switch block.kind {
        case .heading(let level): Text(rich).font(level == 1 ? .title : level == 2 ? .title2 : .headline).bold().accessibilityAddTraits(.isHeader)
        case .bullet: HStack(alignment: .top) { Text("•"); Text(rich) }
        case .quote: HStack { Rectangle().fill(.secondary).frame(width: 3); Text(rich).foregroundStyle(.secondary) }.fixedSize(horizontal: false, vertical: true)
        case .code: Text(block.text).font(.body.monospaced()).padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        case .paragraph: Text(rich)
        }
    }
}

import SwiftUI
import UniformTypeIdentifiers
import AVKit

/// A 4:3 native pager; previews never change the saved originals. Only the selected local movie owns a player.
@MainActor
struct NoteCarousel: View {
    let item: CapturedLink
    var aspectRatio: CGFloat = 4.0 / 3.0
    var onOpenNote: (() -> Void)? = nil
    var showsBody = true
    @State private var page = 0
    private var hasPrimary: Bool { item.kind == .image || item.kind == .file }
    private var count: Int { max(1, item.carouselPageCount - (!showsBody && !item.noteBody.isEmpty ? 1 : 0)) }
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $page) {
                let links = item.allLinks
                ForEach(Array(links.enumerated()), id: \.element.absoluteString) { index, url in
                    NoteLinkButton(item: item, url: url, onOpenNote: onOpenNote).tag(index)
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
                if hasPrimary {
                    filePage(NoteFile(name: item.fileName ?? "Allegato", type: item.contentType ?? "public.data", data: item.attachmentData ?? Data(), framing: item.imageFraming), primary: true, index: links.count)
                        .tag(links.count)
                }
                ForEach(Array(item.noteFiles.enumerated()), id: \.element.id) { offset, file in
                    let index = links.count + (hasPrimary ? 1 : 0) + offset
                    filePage(file, primary: false, index: index).tag(index)
                }
                if item.carouselPageCount == 0 {
                    TextNotePreview(text: item.displayTitle).tag(0)
                }
                if showsBody && !item.noteBody.isEmpty {
                    ScrollView { MarkdownDocumentView(text: item.noteBody).padding(20).padding(.bottom, 30) }
                        .onTapGesture { onOpenNote?() }
                        .tag(count - 1).background(Color.bloomSurface)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay(alignment: .topTrailing) {
                if count > 1 { Text("\(page + 1)/\(count)").font(.caption.monospacedDigit()).padding(8).background(.black.opacity(0.65), in: Capsule()).foregroundStyle(.white).padding(10).accessibilityIdentifier("carousel-position") }
            }
        }.aspectRatio(aspectRatio, contentMode: .fit).clipped().accessibilityElement(children: .contain).accessibilityIdentifier("note-carousel")
            .onChange(of: count) { _, value in page = min(page, max(0, value - 1)) }
    }
    @ViewBuilder private func filePage(_ file: NoteFile, primary: Bool, index: Int) -> some View {
        if let onOpenNote {
            Button(action: onOpenNote) { filePreview(file) }
                .buttonStyle(.plain).accessibilityLabel("Apri nota: \(item.displayTitle)")
        } else if UTType(file.type)?.conforms(to: .movie) == true {
            LocalMoviePage(file: file, active: page == index)
        } else {
            NavigationLink {
                if primary { PrimaryContentView(item: item) }
                else { NoteAttachmentView(item: item, fileID: file.id) }
            } label: {
                filePreview(file)
            }.buttonStyle(.plain).accessibilityLabel(file.name).accessibilityIdentifier("carousel-file-\(file.id)")
        }
    }
    private func filePreview(_ file: NoteFile) -> some View {
        GeometryReader { proxy in
            Color.bloomSurface.overlay {
                if UTType(file.type)?.conforms(to: .image) == true {
                    FramedImage(data: file.data, framing: file.framing ?? ImageFraming(), maximumPixel: 1200, contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                } else if let text = DocumentText.decode(file.data, name: file.name, type: file.type) {
                    MarkdownExcerpt(text: text).padding(20)
                } else {
                    Image(systemName: UTType(file.type)?.conforms(to: .movie) == true ? "play.circle.fill" : "doc").font(.largeTitle).foregroundStyle(BloomBrand.gradient)
                }
            }
        }
    }
}

@MainActor
private struct LocalMoviePage: View {
    let file: NoteFile
    let active: Bool
    @State private var player: AVPlayer?
    @State private var directory: URL?
    @State private var error: String?
    @State private var retry = 0
    var body: some View {
        Group {
            if let player { VideoPlayer(player: player) }
            else if let error { VStack { Text(error); Button("Riprova") { retry += 1 } }.padding() }
            else { ProgressView("Caricamento video…") }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
            .task(id: "\(active)-\(retry)") {
                guard active else { clean(); return }
                do {
                    let file = file
                    let result = try await Task.detached {
                        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("BloomVideo-\(UUID().uuidString)")
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        let ext = UTType(file.type)?.preferredFilenameExtension ?? "mov"
                        let url = directory.appendingPathComponent("video.\(ext)")
                        do { try file.data.write(to: url, options: .atomic) }
                        catch { try? FileManager.default.removeItem(at: directory); throw error }
                        return (directory, url)
                    }.value
                    guard !Task.isCancelled else { try? FileManager.default.removeItem(at: result.0); return }
                    clean(); error = nil; directory = result.0; player = AVPlayer(url: result.1)
                } catch { self.error = error.localizedDescription }
            }
            .onDisappear(perform: clean)
    }
    private func clean() {
        player?.pause(); player = nil
        if let directory { try? FileManager.default.removeItem(at: directory) }
        directory = nil
    }
}

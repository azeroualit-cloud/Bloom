import SwiftUI
import SwiftData
import UIKit

/// Square archive cells with swipe actions; rediscovery uses a portrait post and a separate header.
@MainActor
struct ArchiveTile: View {
    @Environment(\.modelContext) private var context
    let item: CapturedLink
    var compact = false
    var selected = false
    var selecting = false
    @Binding var revealed: UUID?
    let openNote: () -> Void
    let openContent: (ArchiveContentRoute) -> Void
    let editTags: () -> Void
    let select: () -> Void
    let archive: () -> Void
    let delete: () -> Void
    @State private var suppressTapUntil = Date.distantPast
    @State private var opening = false
    @State private var renaming = false
    @State private var draftTitle = ""
    @State private var renameError: String?
    private var isRevealed: Bool { revealed == item.id }

    var body: some View {
        Group {
            if item.modelContext != nil && !item.isDeleted {
                if compact { tile.contextMenu { compactActions } }
                else { feedTile }
            }
        }
        .alert("Modifica titolo", isPresented: $renaming) {
            TextField("Titolo facoltativo", text: $draftTitle)
            Button("Salva") {
                do { try LinkStore.rename(item, title: draftTitle, in: context) }
                catch { renameError = error.localizedDescription }
            }
            Button("Annulla", role: .cancel) { }
        }
        .alert("Modifica non riuscita", isPresented: Binding(get: { renameError != nil }, set: { if !$0 { renameError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(renameError ?? "") }
    }
    private var renameButton: some View {
        Button("Modifica titolo", systemImage: "pencil") { draftTitle = item.title ?? ""; renaming = true }
            .accessibilityIdentifier("note-rename")
    }

    private var feedTile: some View {
        VStack(spacing: 0) {
            footer
            NoteCarousel(item: item, aspectRatio: 3.0 / 4.0)
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("rediscovery-post")
        .task(id: item.allLinks.first) { LinkPreviewController.shared.prepare(for: item, in: context) }
    }
    private var tile: some View {
        GeometryReader { geometry in
            let id = item.id
            let width = geometry.size.width
            let actionWidth = min(112.0, width * 0.65)
            SquareSwipeContainer(surface: AnyView(surface), actions: AnyView(actions), width: width, actionWidth: actionWidth,
                                 revealed: isRevealed, enabled: !selecting, onReveal: { open in revealed = open ? id : nil },
                                 onDrag: { suppressTapUntil = Date().addingTimeInterval(0.8) })
                .frame(width: width, height: width).clipShape(RoundedRectangle(cornerRadius: compact ? 0 : 16))
                .overlay(alignment: .bottom) { if !compact && !isRevealed { footer } }
                .overlay { if selected { RoundedRectangle(cornerRadius: compact ? 0 : 16).strokeBorder(BloomBrand.gradient, lineWidth: 3) } }
        }.aspectRatio(1, contentMode: .fit)
        .task(id: item.allLinks.first) { LinkPreviewController.shared.prepare(for: item, in: context) }
    }

    @ViewBuilder private var compactActions: some View {
        Button("Modifica tag", systemImage: "tag", action: editTags).accessibilityIdentifier("note-context-tags")
        renameButton
        Button("Apri nota", systemImage: "note.text", action: openNote)
            .disabled(selecting).accessibilityIdentifier("note-context-open")
        Button(selected ? "Deseleziona" : "Seleziona", systemImage: "checkmark.circle", action: select).accessibilityIdentifier("note-context-select")
        if item.isArchived { Button("Ripristina", systemImage: "arrow.uturn.backward", action: archive) }
        Button("Elimina", systemImage: "trash", role: .destructive, action: delete)
    }

    private var footer: some View {
        HStack(alignment: .bottom, spacing: 0) {
                Button { if selecting { select() } else { openNote() } } label: {
                    Text(item.displayTitle).font(.subheadline.weight(.semibold)).lineLimit(1)
                        .foregroundStyle(Color.bloomText)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }.buttonStyle(.plain).accessibilityIdentifier("note-title-\(item.id)")
                if !selecting {
                    Menu {
                        Button("Modifica tag", action: editTags)
                        renameButton
                        Button("Apri nota", action: openNote)
                        if item.isArchived { Button("Ripristina", systemImage: "arrow.uturn.backward", action: archive) }
                        Button("Elimina", systemImage: "trash", role: .destructive, action: delete)
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).foregroundStyle(Color.bloomText) }
                        .accessibilityLabel("Azioni nota").accessibilityIdentifier("note-actions-\(item.id)")
                }
            }.padding(.horizontal, 12)
                .background(Color.bloomBackground)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            if item.isArchived {
                Button(action: { revealed = nil; archive() }) {
                    Label("Ripristina", systemImage: "arrow.uturn.backward").font(.caption).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Button(role: .destructive, action: { revealed = nil; delete() }) {
                Label(item.isArchived ? "Elimina definitivamente" : "Elimina", systemImage: "trash").font(.caption).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.background(Color.bloomRaised).accessibilityHidden(!isRevealed)
    }

    private var surface: some View {
        ZStack(alignment: .bottomLeading) {
            Button(action: open) {
                GeometryReader { proxy in
                    Color.bloomSurface
                        .overlay {
                            preview.frame(width: proxy.size.width, height: proxy.size.height).clipped()
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .contentShape(Rectangle())
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityIdentifier("note-open-\(item.id)").accessibilityLabel(item.displayTitle)
                .disabled(opening)
                .highPriorityGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in suppressTapUntil = Date().addingTimeInterval(0.5); select() }, including: compact ? .subviews : .all)
            if hasImage && !compact {
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom).allowsHitTesting(false)
            }
            if item.allLinks.first.map(SocialLink.isVideo) == true {
                Image(systemName: "play.rectangle.fill").font(compact ? .subheadline : .title).foregroundStyle(.white, .black.opacity(0.65))
                    .padding(compact ? 8 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: compact ? .topTrailing : .center).allowsHitTesting(false)
            }
            if item.carouselPageCount > 1 {
                Image(systemName: "square.on.square.fill").font(.caption).padding(8).foregroundStyle(.white).background(.black.opacity(0.5), in: Circle()).padding(6).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).allowsHitTesting(false)
            }
            if selecting {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title2)
                    .foregroundStyle(BloomBrand.gradient).padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).allowsHitTesting(false)
            }
        }
    }
    @ViewBuilder private var preview: some View {
        if let data = item.previewImageData, item.previewSourceURL == item.allLinks.first?.absoluteString {
            CachedPreviewImage(data: data, label: item.displayTitle, maxPixel: compact ? 512 : 768, contentMode: .fill)
        } else if item.kind == .image {
            AttachmentThumbnail(item: item, maximumPixelSize: compact ? 512 : 768, contentMode: .fill)
        } else {
            VStack(alignment: .leading, spacing: compact ? 6 : 12) {
                Image(systemName: item.kind.symbol).font(compact ? .caption : .title2).foregroundStyle(BloomBrand.gradient)
                if compact, let title = item.title, !title.isEmpty {
                    Text(title).font(.caption.weight(.semibold)).lineLimit(2)
                }
                if !item.noteBody.isEmpty { MarkdownExcerpt(text: item.noteBody, font: compact ? .caption : .subheadline).lineLimit(3) }
                else { Text(item.allLinks.first?.host ?? item.fileName ?? item.displayTitle).font(compact ? .caption : .subheadline).lineLimit(3) }
                Spacer(minLength: compact ? 0 : 44)
            }.padding(compact ? 8 : 16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var hasImage: Bool { item.kind == .image || (item.previewImageData != nil && item.previewSourceURL == item.allLinks.first?.absoluteString) }
    private func open() {
        guard item.modelContext != nil && !item.isDeleted else { return }
        guard Date() > suppressTapUntil else { return }
        guard !selecting else { select(); return }
        guard !isRevealed else { revealed = nil; return }
        let count = item.carouselPageCount
        if count > 1 { openNote(); return }
        if let url = item.allLinks.first, SocialLink.instagramPostURL(url) != nil {
            openContent(ArchiveContentRoute(item: item, browser: true))
        } else if let url = item.allLinks.first, SocialLink.opensInApp(url) {
            opening = true
            UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { success in
                Task { @MainActor in
                    opening = false
                    guard item.modelContext != nil && !item.isDeleted else { return }
                    if !success { openContent(ArchiveContentRoute(item: item, browser: true)) }
                }
            }
        } else if item.allLinks.first != nil { openContent(ArchiveContentRoute(item: item, browser: true)) }
        else if item.kind == .image || item.kind == .file { openContent(ArchiveContentRoute(item: item, browser: false)) }
        else { openNote() }
    }
}

struct ArchiveContentRoute: Hashable {
    let item: CapturedLink
    let browser: Bool
}

struct ArchiveContentDestination: View {
    let route: ArchiveContentRoute
    var body: some View {
        if route.item.modelContext != nil && !route.item.isDeleted {
            if route.browser, let url = route.item.allLinks.first { WebContentView(item: route.item, url: url) }
            else { PrimaryContentView(item: route.item) }
        }
    }
}

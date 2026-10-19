import SwiftUI
import SwiftData
import UIKit

/// One square footprint for both archive and rediscovery, including revealed actions.
@MainActor
struct ArchiveTile: View {
    @Environment(\.modelContext) private var context
    let item: CapturedLink
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
    private var isRevealed: Bool { revealed == item.id }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let actionWidth = min(112.0, width * 0.65)
            SquareSwipeContainer(surface: AnyView(surface), actions: AnyView(actions), width: width, actionWidth: actionWidth,
                                 revealed: isRevealed, enabled: !selecting, onReveal: { open in revealed = open ? item.id : nil },
                                 onDrag: { suppressTapUntil = Date().addingTimeInterval(0.8) })
                .frame(width: width, height: width).clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottom) { if !isRevealed { footer } }
                .overlay { if selected { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.accentColor, lineWidth: 3) } }
        }.aspectRatio(1, contentMode: .fit)
        .task(id: item.allLinks.first) { LinkPreviewController.shared.prepare(for: item, in: context) }
    }

    private var footer: some View {
        HStack(alignment: .bottom, spacing: 0) {
                Button { if selecting { select() } else { openNote() } } label: {
                    Text(item.displayTitle).font(.subheadline.weight(.semibold)).lineLimit(2)
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }.buttonStyle(.plain).accessibilityIdentifier("note-title-\(item.id)")
                if !selecting {
                    Menu {
                        Button("Apri nota", action: openNote)
                        Button("Modifica tag", action: editTags)
                        Button(item.isArchived ? "Ripristina" : "Archivia", systemImage: "archivebox", action: archive)
                        Button("Elimina", systemImage: "trash", role: .destructive, action: delete)
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).foregroundStyle(Color.primary) }
                        .accessibilityLabel("Azioni nota").accessibilityIdentifier("note-actions-\(item.id)")
                }
            }.padding(.horizontal, 8).bloomGlass(cornerRadius: 12).padding(6)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            Button(action: { revealed = nil; archive() }) {
                Label(item.isArchived ? "Ripristina" : "Archivia", systemImage: "archivebox")
                    .font(.caption).frame(maxWidth: .infinity, maxHeight: .infinity)
            }.tint(.orange)
            Button(role: .destructive, action: { revealed = nil; delete() }) {
                Label("Elimina", systemImage: "trash").font(.caption).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.background(Color(uiColor: .tertiarySystemGroupedBackground)).accessibilityHidden(!isRevealed)
    }

    private var surface: some View {
        ZStack(alignment: .bottomLeading) {
            Button(action: open) {
                GeometryReader { proxy in
                    ZStack {
                        Color(uiColor: .secondarySystemGroupedBackground)
                        if let data = item.previewImageData, item.previewSourceURL == item.allLinks.first?.absoluteString {
                            CachedPreviewImage(data: data, label: item.displayTitle, maxPixel: 768, contentMode: .fill)
                        } else if item.kind == .image {
                            AttachmentThumbnail(item: item, maximumPixelSize: 768, contentMode: .fill)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: item.kind.symbol).font(.title2).foregroundStyle(Color.accentColor)
                                if !item.noteBody.isEmpty { MarkdownExcerpt(text: item.noteBody).lineLimit(3) }
                                else { Text(item.allLinks.first?.host ?? item.fileName ?? item.displayTitle).font(.subheadline).lineLimit(3) }
                                Spacer(minLength: 44)
                            }.padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }.frame(width: proxy.size.width, height: proxy.size.height).clipped()
                }
            }.buttonStyle(.plain).accessibilityIdentifier("note-open-\(item.id)").accessibilityLabel(item.displayTitle)
                .disabled(opening)
                .highPriorityGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in suppressTapUntil = Date().addingTimeInterval(0.5); select() })
            if hasImage {
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom).allowsHitTesting(false)
            }
            if item.allLinks.first.map(SocialLink.isVideo) == true {
                Image(systemName: "play.circle.fill").font(.title).foregroundStyle(.white, .black.opacity(0.65))
                    .frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
            }
            if selecting {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title2)
                    .foregroundStyle(Color.accentColor).padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).allowsHitTesting(false)
            }
        }
    }
    private var hasImage: Bool { item.kind == .image || (item.previewImageData != nil && item.previewSourceURL == item.allLinks.first?.absoluteString) }
    private func open() {
        guard Date() > suppressTapUntil else { return }
        guard !selecting else { select(); return }
        guard !isRevealed else { revealed = nil; return }
        if let url = item.allLinks.first, SocialLink.isVideo(url) {
            opening = true
            UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { success in
                Task { @MainActor in opening = false; if !success { openContent(ArchiveContentRoute(item: item, browser: true)) } }
            }
        } else if item.kind == .image || item.kind == .file { openContent(ArchiveContentRoute(item: item, browser: false)) }
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
        if route.browser, let url = route.item.allLinks.first { WebContentView(item: route.item, url: url) }
        else { PrimaryContentView(item: route.item) }
    }
}

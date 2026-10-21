import SwiftUI
import UniformTypeIdentifiers

/// Shared typography for feed posts, archive tiles and category collages.
struct TextNotePreview: View {
    let text: String
    var compact = false
    private var style: TextNoteStyle { TextNoteStyle.classify(text) }
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 12) {
            if style == .quote {
                Image(systemName: "quote.opening").font(compact ? .caption : .title2)
                    .foregroundStyle(BloomBrand.gradient).accessibilityHidden(true)
            } else {
                Capsule().fill(BloomBrand.gradient).frame(width: compact ? 18 : 28, height: 3).accessibilityHidden(true)
            }
            if style == .document {
                if compact {
                    MarkdownExcerpt(text: text, font: .caption).lineSpacing(2).lineLimit(5)
                } else {
                    MarkdownDocumentView(text: String(text.prefix(900)))
                        .frame(maxHeight: 260, alignment: .topLeading).clipped()
                }
            } else {
                Text((try? AttributedString(markdown: TextNoteStyle.displayText(text), options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text))
                    .font(compact ? .system(.subheadline, design: .serif, weight: .semibold) : .system(.title2, design: .serif, weight: .medium))
                    .lineSpacing(compact ? 2 : 5).lineLimit(compact ? 5 : nil)
                    .fixedSize(horizontal: false, vertical: !compact)
            }
        }
        .foregroundStyle(Color.bloomText).frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 10 : 24)
        .background {
            if style != .document {
                LinearGradient(colors: [Color.accentColor.opacity(0.14), Color.bloomSurface], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else { Color.bloomSurface }
        }
    }
}

@MainActor
struct NoteVisualPreview: View {
    let item: CapturedLink
    var maximumPixel = 384
    var body: some View {
        GeometryReader { proxy in
            Color.bloomSurface.overlay {
                preview.frame(width: proxy.size.width, height: proxy.size.height).clipped()
            }
        }.clipped().accessibilityHidden(true)
    }
    @ViewBuilder private var preview: some View {
        if let data = item.previewImageData, item.previewSourceURL == item.allLinks.first?.absoluteString {
            CachedPreviewImage(data: data, label: item.displayTitle, maxPixel: maximumPixel, contentMode: .fill)
        } else if item.kind == .image {
            AttachmentThumbnail(item: item, maximumPixelSize: maximumPixel, contentMode: .fill)
        } else if let file = item.noteFiles.first(where: { UTType($0.type)?.conforms(to: .image) == true }) {
            FramedImage(data: file.data, framing: file.framing ?? ImageFraming(), maximumPixel: maximumPixel, contentMode: .fill)
        } else if item.allLinks.isEmpty && item.kind == .text {
            TextNotePreview(text: item.noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.displayTitle : item.noteBody, compact: true)
                .frame(maxHeight: .infinity, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: item.kind.symbol).foregroundStyle(BloomBrand.gradient)
                Text(item.displayTitle).font(.caption.weight(.semibold)).lineLimit(3)
                if let host = item.allLinks.first?.host { Text(host).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            }.padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

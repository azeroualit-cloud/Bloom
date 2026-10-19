import SwiftUI
import SwiftData

/// Reuses cached posters and image framing; only the chosen cover can request metadata.
struct CategoryCover: View {
    @Environment(\.modelContext) private var context
    let name: String
    let symbol: String
    let count: Int
    let item: CapturedLink?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                // The image is an overlay, so its intrinsic aspect ratio cannot move the title.
                Color(uiColor: .secondarySystemGroupedBackground)
                    .overlay {
                        cover.frame(width: proxy.size.width, height: proxy.size.height).clipped()
                    }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(2)
                Text("\(count) note").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
        }
        .task(id: item?.id) {
            if let item, item.modelContext != nil, !item.isDeleted {
                LinkPreviewController.shared.prepare(for: item, in: context)
            }
        }
    }

    @ViewBuilder private var cover: some View {
        if let item, item.modelContext != nil, !item.isDeleted {
            if let data = item.previewImageData, item.previewSourceURL == item.allLinks.first?.absoluteString {
                CachedPreviewImage(data: data, label: name, maxPixel: 512, contentMode: .fill)
            } else if item.kind == .image {
                AttachmentThumbnail(item: item, maximumPixelSize: 512, contentMode: .fill)
            } else if !item.noteBody.isEmpty {
                MarkdownExcerpt(text: item.noteBody).lineLimit(4).padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else { placeholder }
        } else { placeholder }
    }

    private var placeholder: some View {
        Image(systemName: Self.symbols[name.lowercased()] ?? symbol)
            .font(.system(size: 36, weight: .light)).foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static let symbols = [
        "salute": "heart", "alimentazione": "carrot", "studio": "book",
        "lavoro": "briefcase", "progetti": "hammer", "casa": "house",
        "tecnologia": "desktopcomputer", "comunicazione": "bubble.left.and.bubble.right",
        "dating": "heart.text.clipboard", "psicologia": "brain.head.profile", "viaggi": "airplane"
    ]
}

import SwiftUI
import SwiftData

/// Reuses cached posters and image framing; only the chosen cover can request metadata.
struct CategoryCover: View {
    @Environment(\.modelContext) private var context
    let name: String
    let symbol: String
    let count: Int
    let item: CapturedLink?

    private var hasImage: Bool {
        guard let item, item.modelContext != nil, !item.isDeleted else { return false }
        return item.kind == .image || (item.previewImageData != nil && item.previewSourceURL == item.allLinks.first?.absoluteString)
    }
    private var hasExcerpt: Bool {
        guard let item, item.modelContext != nil, !item.isDeleted else { return false }
        return !item.noteBody.isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Color(uiColor: .secondarySystemGroupedBackground)
                if let item, item.modelContext != nil, !item.isDeleted {
                    if let data = item.previewImageData, item.previewSourceURL == item.allLinks.first?.absoluteString {
                        CachedPreviewImage(data: data, label: name, maxPixel: 512, contentMode: .fill)
                    } else if item.kind == .image {
                        AttachmentThumbnail(item: item, maximumPixelSize: 512, contentMode: .fill)
                    } else if !item.noteBody.isEmpty {
                        MarkdownExcerpt(text: item.noteBody).font(.caption).lineLimit(3)
                            .foregroundStyle(.secondary).padding(16).padding(.bottom, 64)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                if hasImage {
                    LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                }
                VStack(alignment: .leading, spacing: 8) {
                    if !hasImage && !hasExcerpt {
                        Image(systemName: Self.symbols[name.lowercased()] ?? symbol)
                            .font(.system(size: 36, weight: .light)).foregroundStyle(Color.accentColor)
                    }
                    Spacer(minLength: 0)
                    Text(name).font(.headline).lineLimit(2)
                    Text("\(count) note").font(.caption).opacity(0.8)
                }.padding(16).foregroundStyle(hasImage ? Color.white : Color.primary)
            }.frame(width: proxy.size.width, height: proxy.size.height).clipped()
        }
        .task(id: item?.id) {
            if let item, item.modelContext != nil, !item.isDeleted {
                LinkPreviewController.shared.prepare(for: item, in: context)
            }
        }
    }

    private static let symbols = [
        "salute": "heart", "alimentazione": "carrot", "studio": "book",
        "lavoro": "briefcase", "progetti": "hammer", "casa": "house",
        "tecnologia": "desktopcomputer", "comunicazione": "bubble.left.and.bubble.right",
        "dating": "heart.text.clipboard", "psicologia": "brain.head.profile", "viaggi": "airplane"
    ]
}

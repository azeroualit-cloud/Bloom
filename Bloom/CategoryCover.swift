import SwiftUI

/// A stable, live collage of up to three recent members, refreshed with their cached previews.
@MainActor
struct CategoryCover: View {
    @Environment(\.modelContext) private var context
    let name: String
    let members: [CapturedLink]
    private var samples: [CapturedLink] { Array(members.prefix(3)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                if let first = samples.first {
                    thumbnail(first)
                    if samples.count > 1 {
                        VStack(spacing: 3) {
                            thumbnail(samples[1])
                            if samples.count > 2 { thumbnail(samples[2]) }
                        }.frame(maxWidth: .infinity)
                    }
                } else {
                    Text("Le tue prossime idee").font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(height: 80).clipShape(RoundedRectangle(cornerRadius: 10))
            Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.bloomText).lineLimit(2)
            Text(ContentLabels.noteCount(members.count)).font(.caption).foregroundStyle(.secondary)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bloomSurface, in: RoundedRectangle(cornerRadius: BloomLayout.radius))
    }
    private func thumbnail(_ note: CapturedLink) -> some View {
        NoteVisualPreview(item: note).frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: note.allLinks.first) {
                guard note.modelContext != nil, !note.isDeleted else { return }
                LinkPreviewController.shared.prepare(for: note, in: context)
            }
    }
}

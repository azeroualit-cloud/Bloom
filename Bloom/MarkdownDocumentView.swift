import SwiftUI

/// Shared rendered document; reading never changes the original Markdown.
struct MarkdownDocumentView: View {
    let text: String
    var query = ""
    var body: some View {
        let blocks = MarkdownBlock.parse(text)
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                blockView(block)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    .background(!query.isEmpty && block.text.localizedStandardContains(query) ? Color.yellow.opacity(0.15) : Color.clear)
                    .id(index)
            }
        }.foregroundStyle(Color.bloomText).accessibilityIdentifier("detail-content-text")
    }
    private func rich(_ value: String) -> AttributedString {
        (try? AttributedString(markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(value)
    }
    @ViewBuilder private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level):
            Text(rich(block.text)).font(headingFont(level)).bold().padding(.top, 4).accessibilityAddTraits(.isHeader)
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if block.text.hasPrefix("[ ] ") || block.text.lowercased().hasPrefix("[x] ") {
                    Image(systemName: block.text.lowercased().hasPrefix("[x]") ? "checkmark.square" : "square")
                    Text(rich(String(block.text.dropFirst(4))))
                } else { Text("•"); Text(rich(block.text)) }
            }
        case .quote:
            HStack { Rectangle().fill(Color.accentColor).frame(width: 3); Text(rich(block.text)) }.fixedSize(horizontal: false, vertical: true)
        case .code:
            ScrollView(.horizontal) { Text(block.text).font(.body.monospaced()).padding(12) }
                .background(Color.bloomSurface, in: RoundedRectangle(cornerRadius: 8))
        case .paragraph: Text(rich(block.text)).lineSpacing(3)
        case .table(let headers, let rows): table(headers: headers, rows: rows)
        }
    }
    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .largeTitle
        case 2: return .title
        case 3: return .title2
        case 4: return .title3
        case 5: return .headline
        default: return .subheadline
        }
    }
    private func table(headers: [String], rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        ForEach(headers.indices, id: \.self) { column in
                            Text(rich(headers[column])).bold().frame(width: column == 0 ? 140 : 220, alignment: .leading).padding(12)
                                .accessibilityAddTraits(.isHeader)
                        }
                    }.background(Color.bloomRaised)
                    ForEach(rows.indices, id: \.self) { row in
                        GridRow {
                            ForEach(headers.indices, id: \.self) { column in
                                Text(rich(rows[row][column])).frame(width: column == 0 ? 140 : 220, alignment: .leading).padding(12)
                                    .accessibilityLabel("\(headers[column]): \(rows[row][column])")
                            }
                        }.background(row.isMultiple(of: 2) ? Color.bloomSurface : Color.bloomBackground)
                    }
                }
            }.clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityIdentifier("markdown-table")
            Label("Scorri la tabella per leggere tutte le colonne", systemImage: "arrow.left.and.right").font(.caption).foregroundStyle(Color.bloomText.opacity(0.8))
        }
    }
}

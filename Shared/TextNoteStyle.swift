import Foundation

/// Presentation only: Markdown sources and saved titles are never rewritten.
enum TextNoteStyle: Equatable {
    case statement, quote, document

    static func classify(_ source: String) -> Self {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let blocks = MarkdownBlock.parse(text)
        guard !text.isEmpty, text.count <= 220,
              text.split(whereSeparator: \.isWhitespace).count <= 36, blocks.count <= 4 else { return .document }
        for block in blocks {
            switch block.kind {
            case .bullet, .table, .code: return .document
            case .paragraph:
                // Preserve numbered lists as documents too.
                if block.text.range(of: #"^\d+[.)]\s"#, options: .regularExpression) != nil { return .document }
            default: break
            }
        }
        return blocks.contains { if case .quote = $0.kind { return true }; return false }
            || text.hasPrefix("“") || text.hasPrefix("«") ? .quote : .statement
    }

    static func displayText(_ source: String) -> String {
        MarkdownBlock.parse(source).map(\.text).joined(separator: "\n")
    }
}

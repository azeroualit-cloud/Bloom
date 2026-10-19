import Foundation

struct MarkdownBlock {
    enum Kind { case paragraph, heading(Int), bullet, quote, code }
    let kind: Kind
    let text: String

    static func parse(_ text: String) -> [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        var code: [String]? = nil
        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("```") {
                if let lines = code { result.append(.init(kind: .code, text: lines.joined(separator: "\n"))); code = nil }
                else { code = [] }
                continue
            }
            if code != nil { code?.append(line); continue }
            if line.isEmpty { continue }
            let hashes = line.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") {
                result.append(.init(kind: .heading(hashes), text: String(line.dropFirst(hashes + 1))))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                result.append(.init(kind: .bullet, text: String(line.dropFirst(2))))
            } else if line.hasPrefix("> ") {
                result.append(.init(kind: .quote, text: String(line.dropFirst(2))))
            } else { result.append(.init(kind: .paragraph, text: line)) }
        }
        if let lines = code { result.append(.init(kind: .code, text: lines.joined(separator: "\n"))) }
        return result
    }
}

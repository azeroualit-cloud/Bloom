import Foundation

struct MarkdownBlock {
    enum Kind {
        case paragraph, heading(Int), bullet, quote, code
        case table(headers: [String], rows: [[String]])
    }
    let kind: Kind
    let text: String

    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: .newlines)
        var result: [MarkdownBlock] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            index += 1
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                let fence = String(line.prefix(3))
                var code: [String] = []
                while index < lines.count && !lines[index].hasPrefix(fence) { code.append(lines[index]); index += 1 }
                if index < lines.count { index += 1 }
                result.append(.init(kind: .code, text: code.joined(separator: "\n")))
                continue
            }
            if index < lines.count, line.contains("|"), isTableSeparator(lines[index]) {
                var headers = tableCells(line)
                if headers.count == tableCells(lines[index]).count {
                    index += 1
                    var rows: [[String]] = []
                    while index < lines.count && lines[index].contains("|") && !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                        rows.append(tableCells(lines[index])); index += 1
                    }
                    let columns = max(headers.count, rows.map(\.count).max() ?? 0)
                    headers += Array(repeating: "", count: columns - headers.count)
                    rows = rows.map { $0 + Array(repeating: "", count: columns - $0.count) }
                    result.append(.init(kind: .table(headers: headers, rows: rows), text: ""))
                    continue
                }
            }
            let hashes = line.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") {
                result.append(.init(kind: .heading(hashes), text: String(line.dropFirst(hashes + 1))))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                result.append(.init(kind: .bullet, text: String(line.dropFirst(2))))
            } else if line.hasPrefix("> ") {
                result.append(.init(kind: .quote, text: String(line.dropFirst(2))))
            } else { result.append(.init(kind: .paragraph, text: line)) }
        }
        return result
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let cells = tableCells(line)
        return !cells.isEmpty && cells.allSatisfy {
            let value = $0.trimmingCharacters(in: CharacterSet(charactersIn: ": "))
            return value.count >= 3 && value.allSatisfy { $0 == "-" }
        }
    }

    /// Escaped pipes and pipes inside inline code belong to the cell.
    static func tableCells(_ line: String) -> [String] {
        var cells: [String] = [], current = ""
        var escaped = false, code = false
        for character in line.trimmingCharacters(in: .whitespaces) {
            if escaped {
                if character != "|" { current.append("\\") }
                current.append(character); escaped = false; continue
            }
            if character == "\\" { escaped = true; continue }
            if character == "`" { code.toggle() }
            if character == "|" && !code { cells.append(current); current = "" }
            else { current.append(character) }
        }
        if escaped { current.append("\\") }
        cells.append(current)
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("|") { cells.removeFirst() }
        if line.trimmingCharacters(in: .whitespaces).hasSuffix("|"), cells.last?.isEmpty == true { cells.removeLast() }
        return cells.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

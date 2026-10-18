import Foundation
import UniformTypeIdentifiers

enum DocumentText {
    static let maximumPreviewBytes = 512 * 1024

    static func decode(_ data: Data, name: String, type: String?) -> String? {
        guard data.count <= maximumPreviewBytes else { return nil }
        let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
        let textExtensions = ["md", "markdown", "txt", "log", "csv", "json", "yaml", "yml"]
        guard textExtensions.contains(ext) || type.flatMap { UTType($0) }?.conforms(to: .text) == true else { return nil }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)
        }
        guard let text = String(data: data, encoding: .utf8), !text.contains("\0") else { return nil }
        return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
    }
}

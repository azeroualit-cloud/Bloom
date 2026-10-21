import Foundation

enum ContentLabels {
    static func noteCount(_ count: Int) -> String { count == 1 ? "1 nota" : "\(count) note" }
    static func linkTitle(_ url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host == "tiktok.com" || host.hasSuffix(".tiktok.com") { return "Video TikTok" }
        if host == "instagram.com" || host.hasSuffix(".instagram.com") { return "Post Instagram" }
        if host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com") { return "Video YouTube" }
        return host.isEmpty ? "Link salvato" : "Link da \(host.hasPrefix("www.") ? String(host.dropFirst(4)) : host)"
    }
}

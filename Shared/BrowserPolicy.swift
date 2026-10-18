import Foundation

enum BrowserPolicy {
    static func isWebURL(_ url: URL) -> Bool { (try? LinkValidation.validate(url)) != nil }

    static func allows(_ url: URL, mainFrame: Bool) -> Bool {
        if isWebURL(url) || url.absoluteString == "about:blank" { return true }
        // In-page frames can use WebKit-managed content, never local filesystem URLs.
        guard !mainFrame else { return false }
        return ["about", "blob", "data"].contains(url.scheme?.lowercased() ?? "")
    }
}

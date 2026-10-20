import Foundation

/// Private recovery handoff from a background intent to the app. No App Group is needed.
@MainActor
enum CaptureFailureInbox {
    static let ready = Notification.Name("Bloom.captureFailureReady")
    private static let key = "capture.pendingFailures"
    struct Failure: Equatable {
        let url: URL?
        let message: String
    }
    static func record(url: URL, message: String, defaults: UserDefaults = .standard) {
        var failures = defaults.array(forKey: key) as? [[String: String]] ?? []
        failures.removeAll { $0["url"] == url.absoluteString }
        failures.append(["url": url.absoluteString, "message": message])
        defaults.set(failures, forKey: key)
    }
    static func take(defaults: UserDefaults = .standard) -> Failure? {
        var failures = defaults.array(forKey: key) as? [[String: String]] ?? []
        guard !failures.isEmpty else { return nil }
        let first = failures.removeFirst()
        if failures.isEmpty { defaults.removeObject(forKey: key) }
        else { defaults.set(failures, forKey: key) }
        return Failure(url: first["url"].flatMap(URL.init(string:)), message: first["message"] ?? "Salvataggio non riuscito.")
    }
}

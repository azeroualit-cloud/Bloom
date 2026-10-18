import Foundation

enum CaptureRoute {
    static func link(from route: URL) throws -> URL {
        guard let parts = URLComponents(url: route, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "bloom", parts.host == "capture",
              parts.path.isEmpty || parts.path == "/",
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.fragment == nil,
              let items = parts.queryItems, items.count == 1,
              items[0].name == "url", let value = items[0].value,
              let url = URL(string: value) else { throw CaptureError.invalidURL }
        return try LinkValidation.validate(url)
    }
}

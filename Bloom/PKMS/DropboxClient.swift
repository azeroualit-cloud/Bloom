import Foundation
import Security

struct DropboxCredentials: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var accountID: String
    var appKey: String
}

struct DropboxCredentialVault {
    private let service = "app.bloom.dropbox.oauth"
    func load() throws -> DropboxCredentials? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw DropboxFailure.storage("Portachiavi non accessibile (\(status)).") }
        return try JSONDecoder().decode(DropboxCredentials.self, from: data)
    }
    func save(_ credentials: DropboxCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = base
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw DropboxFailure.storage("Impossibile conservare l’accesso Dropbox.") }
        } else if status != errSecSuccess { throw DropboxFailure.storage("Impossibile aggiornare l’accesso Dropbox.") }
    }
    func disconnect() throws {
        let status = SecItemDelete(base as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw DropboxFailure.storage("Impossibile scollegare Dropbox.") }
    }
    private var base: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "pkms"] }
}

actor DropboxClient: DropboxServing {
    static let shared = DropboxClient()
    static func redirect(for appKey: String) -> String { "db-\(appKey)://2/token" }
    private let session: URLSession
    private let accessTokenProvider: (@Sendable () async throws -> String)?
    private let vault = DropboxCredentialVault()
    private var credentialGeneration = UUID()
    private var refreshing: Task<DropboxCredentials, Error>?
    init(session: URLSession = .shared, accessTokenProvider: (@Sendable () async throws -> String)? = nil) {
        self.session = session; self.accessTokenProvider = accessTokenProvider
    }
    func isConnected() throws -> Bool { try vault.load() != nil }
    func disconnect() throws {
        credentialGeneration = UUID(); refreshing?.cancel(); refreshing = nil
        try vault.disconnect()
    }

    func connect(code: String, verifier: String, appKey: String, expectedAccount: String?) async throws -> String {
        let response = try await tokenRequest(["grant_type": "authorization_code", "code": code,
                                              "code_verifier": verifier, "client_id": appKey, "redirect_uri": Self.redirect(for: appKey)])
        guard let refresh = response.refreshToken, let account = response.accountID else { throw DropboxFailure.invalidResponse }
        if let expectedAccount, expectedAccount != account { throw DropboxAuthError.differentAccount }
        credentialGeneration = UUID()
        try vault.save(DropboxCredentials(accessToken: response.accessToken, refreshToken: refresh,
                                         expiresAt: Date().addingTimeInterval(response.expiresIn), accountID: account, appKey: appKey))
        return account
    }
    func accountID() throws -> String? { try vault.load()?.accountID }

    func list(path: String, recursive: Bool, cursor: String?) async throws -> DropboxListing {
        let endpoint = cursor == nil ? "files/list_folder" : "files/list_folder/continue"
        let parameters: [String: Any] = cursor.map { ["cursor": $0] } ?? ["path": path, "recursive": recursive, "include_deleted": true, "limit": 1000]
        let data = try await rpc(endpoint, parameters)
        return try JSONDecoder().decode(DropboxListing.self, from: data)
    }
    func download(id: String) async throws -> DropboxDownload {
        let arguments = try Self.headerJSON(["path": id])
        let (data, response) = try await perform(host: "content.dropboxapi.com", endpoint: "files/download", body: nil,
                                               headers: ["Dropbox-API-Arg": arguments])
        guard data.count <= 8 * 1024 * 1024 else { throw DropboxFailure.tooLarge }
        guard let metadata = response.value(forHTTPHeaderField: "Dropbox-API-Result")?.data(using: .utf8),
              let text = String(data: data, encoding: .utf8) else { throw DropboxFailure.unsupportedText }
        return DropboxDownload(text: text, metadata: try JSONDecoder().decode(DropboxEntry.self, from: metadata))
    }
    func upload(path: String, revision: String, text: String) async throws -> DropboxEntry {
        guard text.utf8.count <= 8 * 1024 * 1024 else { throw DropboxFailure.tooLarge }
        let args: [String: Any] = ["path": path, "mode": [".tag": "update", "update": revision], "autorename": false, "mute": true, "strict_conflict": true]
        let (data, _) = try await perform(host: "content.dropboxapi.com", endpoint: "files/upload", body: Data(text.utf8),
                                         headers: ["Dropbox-API-Arg": try Self.headerJSON(args), "Content-Type": "application/octet-stream"])
        return try JSONDecoder().decode(DropboxEntry.self, from: data)
    }
    private func rpc(_ endpoint: String, _ body: [String: Any]) async throws -> Data {
        try await perform(host: "api.dropboxapi.com", endpoint: endpoint, body: JSONSerialization.data(withJSONObject: body),
                          headers: ["Content-Type": "application/json"]).0
    }
    private func accessToken() async throws -> String {
        if let accessTokenProvider { return try await accessTokenProvider() }
        guard let credentials = try vault.load() else { throw DropboxFailure.notConnected }
        if credentials.expiresAt > Date().addingTimeInterval(90) { return credentials.accessToken }
        if let refreshing { return try await refreshing.value.accessToken }
        let generation = credentialGeneration
        let task = Task<DropboxCredentials, Error> {
            let token = try await self.tokenRequest(["grant_type": "refresh_token", "refresh_token": credentials.refreshToken, "client_id": credentials.appKey])
            try Task.checkCancellation()
            guard generation == self.credentialGeneration else { throw DropboxFailure.notConnected }
            var updated = credentials
            updated.accessToken = token.accessToken
            updated.expiresAt = Date().addingTimeInterval(token.expiresIn)
            try self.vault.save(updated)
            return updated
        }
        refreshing = task
        defer { refreshing = nil }
        return try await task.value.accessToken
    }
    private func perform(host: String, endpoint: String, body: Data?, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: URL(string: "https://\(host)/2/\(endpoint)")!)
        request.httpMethod = "POST"; request.timeoutInterval = 45
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DropboxFailure.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw DropboxFailure.unauthorized }
            if http.statusCode == 409 {
                let summary = (try? JSONDecoder().decode(APIError.self, from: data).errorSummary) ?? ""
                if summary.contains("reset") { throw DropboxFailure.cursorReset }
                if summary.contains("not_found") { throw DropboxFailure.remoteMissing }
                throw DropboxFailure.conflict
            }
            throw DropboxFailure.provider(http.statusCode)
        }
        return (data, http)
    }
    private struct APIError: Decodable { let errorSummary: String; enum CodingKeys: String, CodingKey { case errorSummary = "error_summary" } }
    private struct Token: Decodable {
        let accessToken: String; let refreshToken: String?; let expiresIn: Double; let accountID: String?
        enum CodingKeys: String, CodingKey { case accessToken = "access_token", refreshToken = "refresh_token", expiresIn = "expires_in", accountID = "account_id" }
    }
    private func tokenRequest(_ parameters: [String: String]) async throws -> Token {
        var request = URLRequest(url: URL(string: "https://api.dropboxapi.com/oauth2/token")!)
        request.httpMethod = "POST"; request.timeoutInterval = 45
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        request.httpBody = parameters.sorted { $0.key < $1.key }.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DropboxFailure.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw DropboxFailure.unauthorized }
        return try JSONDecoder().decode(Token.self, from: data)
    }
    /// Dropbox requires ASCII HTTP headers, including paths with Unicode characters.
    static func headerJSON(_ object: [String: Any]) throws -> String {
        let json = String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
        return json.utf16.map { $0 < 128 ? String(UnicodeScalar($0)!) : String(format: "\\u%04x", $0) }.joined()
    }
}

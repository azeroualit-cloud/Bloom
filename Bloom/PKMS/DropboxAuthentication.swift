import AuthenticationServices
import CryptoKit
import Security
import UIKit

enum DropboxAuthError: LocalizedError {
    case invalidKey, cancelled, invalidCallback, differentAccount, randomUnavailable
    var errorDescription: String? {
        switch self {
        case .invalidKey: return "Inserisci l’App key pubblica dell’app Dropbox configurata per Bloom."
        case .cancelled: return "Collegamento annullato. I documenti locali sono conservati."
        case .invalidCallback: return "Risposta di autenticazione non valida. Riprova il collegamento."
        case .differentAccount: return "Questa cartella appartiene a un altro account Dropbox. Ricollega l’account originale per proteggere le note locali."
        case .randomUnavailable: return "Impossibile avviare un’autenticazione sicura. Riprova."
        }
    }
}

@MainActor
final class DropboxAuthentication: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    func connect(appKey: String, expectedAccount: String?) async throws -> String {
        defer { session = nil }
        let key = appKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.range(of: "^[A-Za-z0-9]+$", options: .regularExpression) != nil else { throw DropboxAuthError.invalidKey }
        let verifier = try Self.random(), state = try Self.random()
        let challenge = Self.base64(Data(SHA256.hash(data: Data(verifier.utf8))))
        var url = URLComponents(string: "https://www.dropbox.com/oauth2/authorize")!
        url.queryItems = ["client_id": key, "response_type": "code", "token_access_type": "offline", "redirect_uri": DropboxClient.redirect,
                          "code_challenge": challenge, "code_challenge_method": "S256", "state": state,
                          "scope": "files.metadata.read files.content.read files.content.write"].map { URLQueryItem(name: $0.key, value: $0.value) }
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url.url!, callbackURLScheme: "bloom-dropbox") { callback, error in
                if let callback { continuation.resume(returning: callback) }
                else { continuation.resume(throwing: error ?? DropboxAuthError.cancelled) }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            if !session.start() { continuation.resume(throwing: DropboxAuthError.invalidCallback) }
        }
        let components = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        let values = components?.queryItems ?? []
        guard callback.scheme == "bloom-dropbox", callback.host == "oauth",
              values.first(where: { $0.name == "state" })?.value == state,
              let code = values.first(where: { $0.name == "code" })?.value else { throw DropboxAuthError.invalidCallback }
        return try await DropboxClient.shared.connect(code: code, verifier: verifier, appKey: key, expectedAccount: expectedAccount)
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
    private static func random() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw DropboxAuthError.randomUnavailable }
        return base64(Data(bytes))
    }
    private static func base64(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

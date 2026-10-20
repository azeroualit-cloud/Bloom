import XCTest
@testable import Bloom

private final class DropboxWireFixture: URLProtocol {
    static var respond: ((URLRequest) throws -> (Int, [String: String], Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let respond = Self.respond else { throw URLError(.badServerResponse) }
            let (status, headers, data) = try respond(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}

final class DropboxClientTests: XCTestCase {
    private func client(_ response: @escaping (URLRequest) throws -> (Int, [String: String], Data)) -> DropboxClient {
        DropboxWireFixture.respond = response
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DropboxWireFixture.self]
        let session = URLSession(configuration: configuration)
        addTeardownBlock { session.invalidateAndCancel(); DropboxWireFixture.respond = nil }
        return DropboxClient(session: session, accessTokenProvider: { "fixture-token" })
    }
    func testUploadUsesConditionalRevisionAndOriginalMarkdownBytes() async throws {
        let markdown = "---\nkey: value\n---\n# Perché 🧠\r\n"
        let api = client { request in
            XCTAssertEqual(request.url?.absoluteString, "https://content.dropboxapi.com/2/files/upload")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")
            let header = try XCTUnwrap(request.value(forHTTPHeaderField: "Dropbox-API-Arg"))
            let arguments = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(header.utf8)) as? [String: Any])
            XCTAssertEqual(arguments["path"] as? String, "id:original")
            XCTAssertEqual(arguments["mode"] as? [String: String], [".tag": "update", "update": "revision-from-download"])
            XCTAssertEqual(arguments["strict_conflict"] as? Bool, true)
            XCTAssertEqual(arguments["autorename"] as? Bool, false)
            // URLSession may expose the request body as a stream to URLProtocol.
            let data: Data
            if let body = request.httpBody { data = body }
            else {
                let stream = try XCTUnwrap(request.httpBodyStream)
                stream.open(); defer { stream.close() }
                var body = Data(), buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    body.append(buffer, count: count)
                }
                data = body
            }
            XCTAssertEqual(data, Data(markdown.utf8))
            return (200, [:], Data(#"{".tag":"file","name":"Nota.md","id":"id:original","path_lower":"/pkms/nota.md","rev":"new-revision","size":42}"#.utf8))
        }
        let result = try await api.upload(path: "id:original", revision: "revision-from-download", text: markdown)
        XCTAssertEqual(result.rev, "new-revision")
    }
    func testProviderRevisionConflictDoesNotBecomeSuccessfulUpload() async throws {
        let api = client { _ in (409, [:], Data(#"{"error_summary":"path/conflict/file/"}"#.utf8)) }
        do {
            _ = try await api.upload(path: "id:original", revision: "stale", text: "Draft")
            XCTFail("Revision mismatch must be reported")
        } catch { XCTAssertEqual(error as? DropboxFailure, .conflict) }
    }
    func testRevokedAuthorizationAndCursorResetAreDistinctRecoverableErrors() async throws {
        let api = client { request in
            if request.url?.path.hasSuffix("continue") == true {
                return (409, [:], Data(#"{"error_summary":"reset/"}"#.utf8))
            }
            return (401, [:], Data())
        }
        do { _ = try await api.list(path: "/pkms", recursive: true, cursor: nil); XCTFail("Revoked token accepted") }
        catch { XCTAssertEqual(error as? DropboxFailure, .unauthorized) }
        do { _ = try await api.list(path: "/pkms", recursive: true, cursor: "old"); XCTFail("Reset cursor accepted") }
        catch { XCTAssertEqual(error as? DropboxFailure, .cursorReset) }
    }
    func testDownloadUsesMetadataRevisionAndDoesNotInterpretMarkdown() async throws {
        let markdown = "---\nunknown: true\n---\n[[Untouched]]\n"
        let api = client { request in
            XCTAssertEqual(request.url?.path, "/2/files/download")
            let header = #"{".tag":"file","name":"Nota.md","id":"id:original","path_lower":"/pkms/nota.md","rev":"base","size":42}"#
            return (200, ["Dropbox-API-Result": header], Data(markdown.utf8))
        }
        let result = try await api.download(id: "id:original")
        XCTAssertEqual(result.text, markdown)
        XCTAssertEqual(result.metadata.rev, "base")
    }
}

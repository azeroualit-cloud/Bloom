import XCTest
import WebKit
@testable import Bloom

final class BrowserTests: XCTestCase {
    func testInstagramPhotoPostsUseCanonicalInternalEmbedsWhileReelsKeepExternalPlayback() {
        for raw in ["https://www.instagram.com/p/Ab_c-123/?img_index=2&igsh=test", "https://instagram.com/creator/p/Ab_c-123/"] {
            let url = URL(string: raw)!
            XCTAssertEqual(SocialLink.instagramPostURL(url)?.absoluteString, "https://www.instagram.com/p/Ab_c-123/")
            XCTAssertEqual(SocialLink.instagramEmbedURL(url)?.absoluteString, "https://www.instagram.com/p/Ab_c-123/embed/")
            XCTAssertFalse(SocialLink.opensInApp(url))
        }
        let reel = URL(string: "https://www.instagram.com/reel/Ab_c-123/")!
        XCTAssertNil(SocialLink.instagramEmbedURL(reel))
        XCTAssertTrue(SocialLink.opensInApp(reel))
        XCTAssertTrue(SocialLink.isVideo(reel))
        for raw in ["https://instagram.com.attacker.test/p/abc/", "https://evilinstagram.com/p/abc/", "file:///p/abc/", "instagram://p/abc/", "https://instagram.com/p/abc/more/", "https://instagram.com/p/a%22b/"] {
            XCTAssertNil(SocialLink.instagramEmbedURL(URL(string: raw)!), raw)
        }
    }

    func testWebPolicyRejectsLocalFilesAndExternalAppSchemes() {
        for raw in ["https://example.com/path", "http://example.com", "about:blank"] {
            XCTAssertTrue(BrowserPolicy.allows(URL(string: raw)!, mainFrame: true))
        }
        for raw in ["file:///private/data", "javascript:alert(1)", "bloom://capture?url=https://example.com",
                    "instagram://media", "data:text/html,test"] {
            XCTAssertFalse(BrowserPolicy.allows(URL(string: raw)!, mainFrame: true))
        }
        XCTAssertTrue(BrowserPolicy.allows(URL(string: "blob:https://example.com/id")!, mainFrame: false))
        XCTAssertFalse(BrowserPolicy.allows(URL(string: "file:///private/data")!, mainFrame: false))
    }

    @MainActor
    func testConfigurationPersistsWebsiteDataAndRequiresPlaybackGesture() {
        let configuration = BrowserSession.configuration()
        XCTAssertTrue(configuration.websiteDataStore.isPersistent)
        XCTAssertTrue(configuration.allowsInlineMediaPlayback)
        XCTAssertTrue(configuration.mediaTypesRequiringUserActionForPlayback.contains(.video))
        XCTAssertTrue(configuration.mediaTypesRequiringUserActionForPlayback.contains(.audio))
    }

    @MainActor
    func testBrowserLoadsLocalHTMLAndTracksTitle() async throws {
        let browser = BrowserSession(url: URL(string: "https://example.invalid/")!, loadImmediately: false)
        browser.webView.loadHTMLString(
            "<html><head><title>Bloom fixture</title></head><body><p id='content'>Contenuto locale</p></body></html>",
            baseURL: URL(string: "https://example.invalid/"))
        let deadline = Date().addingTimeInterval(30)
        while browser.pageTitle != "Bloom fixture" && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(browser.pageTitle, "Bloom fixture")
        let content = try await browser.webView.evaluateJavaScript("document.getElementById('content').textContent")
        XCTAssertEqual(content as? String, "Contenuto locale")
        XCTAssertNil(browser.error)
        browser.stop()
    }
}

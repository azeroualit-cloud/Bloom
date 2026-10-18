import Foundation
import WebKit
import Observation

@MainActor
@Observable
final class BrowserSession: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    let originalURL: URL
    var currentURL: URL
    var pageTitle = ""
    var isLoading = false
    var progress = 0.0
    var canGoBack = false
    var canGoForward = false
    var error: String?
    var notice: String?
    var clearingData = false
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    static func configuration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        return configuration
    }

    init(url: URL, loadImmediately: Bool = true) {
        originalURL = url
        currentURL = url
        webView = WKWebView(frame: .zero, configuration: Self.configuration())
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        observations = [observe(\.url), observe(\.title), observe(\.isLoading),
                        observe(\.estimatedProgress), observe(\.canGoBack), observe(\.canGoForward)]
        if loadImmediately { load(url) }
    }

    private func observe<Value>(_ keyPath: KeyPath<WKWebView, Value>) -> NSKeyValueObservation {
        webView.observe(keyPath, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.synchronize() }
        }
    }

    private func synchronize() {
        if let url = webView.url, BrowserPolicy.isWebURL(url) { currentURL = url }
        pageTitle = webView.title ?? ""
        isLoading = webView.isLoading
        progress = webView.estimatedProgress
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    func load(_ url: URL) {
        guard BrowserPolicy.isWebURL(url) else { error = "Questo indirizzo non è una pagina web valida."; return }
        error = nil
        notice = nil
        isLoading = true
        progress = 0
        webView.load(URLRequest(url: url, timeoutInterval: 30))
    }

    func retry() { load(currentURL) }
    func stop() { webView.stopLoading(); synchronize() }
    func back() { if webView.canGoBack { webView.goBack() } }
    func forward() { if webView.canGoForward { webView.goForward() } }

    func clearWebsiteData() async {
        guard !clearingData else { return }
        clearingData = true
        webView.stopLoading()
        await webView.configuration.websiteDataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        clearingData = false
        load(originalURL)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let mainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        guard BrowserPolicy.allows(url, mainFrame: mainFrame) else {
            notice = "Il sito richiede un’apertura esterna. Puoi usare Apri all’esterno oppure continuare qui."
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame && !navigationResponse.canShowMIMEType {
            notice = "Questo contenuto non è visualizzabile nel browser. Usa Apri all’esterno."
            decisionHandler(.cancel)
            return
        }
        if navigationResponse.isForMainFrame,
           let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 {
            error = "Il sito ha risposto con errore HTTP \(response.statusCode)."
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        error = nil
        notice = nil
        synchronize()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { synchronize() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failed(error)
    }

    private func failed(_ error: Error) {
        let failure = error as NSError
        // A cancelled navigation or intercepted app redirect is not a failed page load.
        if failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled { return }
        if failure.domain == "WebKitErrorDomain" && failure.code == 102 { return }
        self.error = error.localizedDescription
        synchronize()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        error = "La pagina è stata interrotta. Premi Riprova per riaprirla."
        synchronize()
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url, BrowserPolicy.isWebURL(url) {
            load(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.deny)
    }
}

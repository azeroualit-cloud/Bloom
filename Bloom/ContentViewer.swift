import SwiftUI
import WebKit
import UIKit

struct ContentViewer: View {
    let item: CapturedLink
    var body: some View { NoteDetailView(item: item) }
}

struct PrimaryContentView: View {
    let item: CapturedLink
    var body: some View {
        if item.kind == .link, let url = URL(string: item.urlString), BrowserPolicy.isWebURL(url) {
            WebContentView(item: item, url: url)
        } else if item.kind == .image {
            ImageContentView(item: item)
        } else if item.kind == .text {
            TextContentView(item: item)
        } else if let data = item.attachmentData,
                  let text = DocumentText.decode(data, name: item.fileName ?? "contenuto", type: item.contentType) {
            TextContentView(item: item, source: .attachment, originalText: text)
        } else { LinkDetailView(link: item) }
    }
}

@MainActor
struct WebContentView: View {
    let item: CapturedLink
    let url: URL
    @State private var browser: BrowserSession?

    var body: some View {
        Group {
            if let browser { BrowserScreen(item: item, browser: browser) }
            else { ProgressView("Apertura contenuto…") }
        }
        .task { if browser == nil { browser = BrowserSession(url: url) } }
    }
}

@MainActor
private struct BrowserScreen: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var context
    let item: CapturedLink
    let browser: BrowserSession
    @State private var showingDetails = false
    @State private var confirmClear = false
    @State private var externalError = false

    var body: some View {
        VStack(spacing: 0) {
            Text(browser.currentURL.absoluteString)
                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                .textSelection(.enabled).padding(.horizontal).padding(.vertical, 8)
            if browser.isLoading { ProgressView(value: browser.progress).accessibilityLabel("Caricamento pagina") }
            if browser.clearingData { ProgressView("Cancellazione dati di navigazione…").padding() }
            if let error = browser.error {
                VStack(alignment: .leading, spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle")
                    HStack {
                        Button("Riprova") { browser.retry() }
                        Button("Apri all’esterno", action: openExternal)
                    }
                }.font(.subheadline).padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
            }
            if let notice = browser.notice {
                VStack(alignment: .leading, spacing: 8) {
                    Text(notice)
                    HStack {
                        Button("Apri all’esterno", action: openExternal)
                        Button("Chiudi avviso") { browser.notice = nil }
                    }
                }.font(.subheadline).padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
            }
            BrowserSurface(session: browser)
        }
        .navigationTitle(item.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Dettagli") { showingDetails = true } }
            ToolbarItem(placement: .secondaryAction) {
                Button("Cancella dati di navigazione", systemImage: "trash") { confirmClear = true }
                    .disabled(browser.clearingData)
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Indietro", systemImage: "chevron.backward") { browser.back() }.disabled(!browser.canGoBack)
                Button("Avanti", systemImage: "chevron.forward") { browser.forward() }.disabled(!browser.canGoForward)
                Button(browser.isLoading ? "Interrompi" : "Ricarica", systemImage: browser.isLoading ? "xmark" : "arrow.clockwise") {
                    if browser.isLoading { browser.stop() } else { browser.retry() }
                }.disabled(browser.clearingData)
                Spacer()
                ShareLink(item: browser.currentURL) { Label("Condividi pagina", systemImage: "square.and.arrow.up") }
                Button("Copia link", systemImage: "doc.on.doc") { UIPasteboard.general.string = browser.currentURL.absoluteString }
                Button("Apri all’esterno", systemImage: "safari", action: openExternal)
            }
        }
        .sheet(isPresented: $showingDetails) {
            NavigationStack {
                LinkDetailView(link: item)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fine") { showingDetails = false } } }
            }
        }
        .confirmationDialog("Cancellare i dati di navigazione?", isPresented: $confirmClear) {
            Button("Cancella dati web", role: .destructive) { Task { await browser.clearWebsiteData() } }
            Button("Annulla", role: .cancel) { }
        } message: {
            Text("Rimuove cookie e dati dei siti dal browser di Bloom e può disconnetterti. I contenuti salvati e le raccolte restano nell’app.")
        }
        .alert("Apertura esterna non riuscita", isPresented: $externalError) {
            Button("OK", role: .cancel) { }
        } message: { Text("Puoi copiare o condividere l’indirizzo della pagina dalla barra del browser.") }
    }

    private func openExternal() {
        openURL(browser.currentURL) { accepted in externalError = !accepted }
    }
}

@MainActor
private struct BrowserSurface: UIViewRepresentable {
    let session: BrowserSession
    func makeUIView(context: Context) -> WKWebView { session.webView }
    func updateUIView(_ view: WKWebView, context: Context) { }
    static func dismantleUIView(_ view: WKWebView, coordinator: ()) { view.stopLoading() }
}

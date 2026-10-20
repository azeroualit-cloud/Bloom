import SwiftUI
import SwiftData

@main
@MainActor
struct BloomApp: App {
    var body: some Scene {
        WindowGroup { StorageRootView() }
    }
}

@MainActor
private struct StorageRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var attempt: StorageAttempt?
    @State private var pendingURL: URL?
    @State private var notice: String?
    @State private var captureError: String?

    var body: some View {
        Group {
            if let attempt {
                switch attempt.result {
                case .success(let container):
                    BloomHomeView().modelContainer(container)
                case .failure(let error):
                    StorageFailureView(diagnostics: StorageDiagnostics(
                        appInfo: Bundle.main.infoDictionary ?? [:], error: error)) {
                        self.attempt = StorageAttempt.load()
                        savePendingURL()
                    }
                }
            } else { ProgressView("Apertura archivio…") }
        }
        .task {
            if attempt == nil {
                attempt = StorageAttempt.load()
            }
            if captureError == nil && !restoreIntentFailure() { savePendingURL() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { _ = restoreIntentFailure() }
        }
        .onReceive(NotificationCenter.default.publisher(for: CaptureFailureInbox.ready)) { _ in
            _ = restoreIntentFailure()
        }
        .onOpenURL { route in
            do {
                pendingURL = try CaptureRoute.link(from: route)
                if attempt == nil { attempt = StorageAttempt.load() }
                savePendingURL()
            } catch { captureError = error.localizedDescription }
        }
        .safeAreaInset(edge: .bottom) {
            if let notice {
                HStack {
                    Label(notice, systemImage: "checkmark.circle")
                    Spacer()
                    Button("Chiudi") { self.notice = nil }
                }
                .padding().background(.regularMaterial)
            }
        }
        .alert("Link non salvato", isPresented: Binding(
            get: { captureError != nil }, set: { if !$0 { captureError = nil } })) {
            if pendingURL != nil { Button("Riprova") { savePendingURL() } }
            Button("Chiudi", role: .cancel) { }
        } message: { Text(captureError ?? "") }
    }

    @discardableResult
    private func restoreIntentFailure() -> Bool {
        guard captureError == nil, let failure = CaptureFailureInbox.take() else { return false }
        pendingURL = failure.url
        captureError = failure.message
        return true
    }

    private func savePendingURL() {
        guard let url = pendingURL, let attempt else { return }
        guard case .success(let container) = attempt.result else { return }
        do {
            let inserted = try LinkStore.capture(url, into: container.mainContext)
            pendingURL = nil
            notice = inserted ? "Link salvato in Bloom" : "Link già presente in Bloom."
        } catch { captureError = error.localizedDescription }
    }
}

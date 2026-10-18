import SwiftUI
import SwiftData

@main
@MainActor
struct BloomApp: App {
    var body: some Scene {
        WindowGroup {
            StorageRootView()
        }
    }
}

@MainActor
private struct StorageRootView: View {
    @State private var attempt: StorageAttempt?

    var body: some View {
        Group {
            if let attempt {
                switch attempt.result {
                case .success(let container):
                    LibraryView().modelContainer(container)
                case .failure:
                    StorageFailureView(diagnostics: attempt.diagnostics) {
                        self.attempt = StorageAttempt.load()
                    }
                }
            } else {
                ProgressView("Apertura archivio…")
            }
        }
        .task {
            if attempt == nil { attempt = StorageAttempt.load() }
        }
    }
}

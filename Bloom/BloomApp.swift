import SwiftUI
import SwiftData

@main
@MainActor
struct BloomApp: App {
    private let storage: Result<ModelContainer, Error>

    init() {
        storage = Result { try LinkStore.container(at: CaptureInbox.sharedRoot()) }
    }

    var body: some Scene {
        WindowGroup {
            switch storage {
            case .success(let container):
                LibraryView().modelContainer(container)
            case .failure(let error):
                ContentUnavailableView("Archivio non disponibile", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text(error.localizedDescription))
            }
        }
    }
}

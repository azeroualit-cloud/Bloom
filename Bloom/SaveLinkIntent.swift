import AppIntents
import Foundation
import SwiftData

struct SaveLinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Salva link in Bloom"
    static var description = IntentDescription("Salva un URL nella raccolta locale di Bloom.")
    static var openAppWhenRun = true

    @Parameter(title: "URL") var url: URL

    static var parameterSummary: some ParameterSummary {
        Summary("Salva \(\.$url) in Bloom")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try LocalLibrary.open()
        let inserted = try LinkStore.capture(url, into: container.mainContext)
        let message: IntentDialog = inserted ? "Link salvato in Bloom" : "Link già presente in Bloom"
        return .result(dialog: message)
    }
}

struct BloomShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SaveLinkIntent(), phrases: ["Salva un link in \(.applicationName)"],
                    shortTitle: "Salva link", systemImageName: "tray.and.arrow.down")
    }
}

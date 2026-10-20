import AppIntents
import Foundation
import SwiftData

struct SaveLinkIntent: AppIntent, ForegroundContinuableIntent {
    static var title: LocalizedStringResource = "Salva link in Bloom"
    static var description = IntentDescription("Salva un URL nella raccolta locale di Bloom.")
    static var openAppWhenRun = false

    @Parameter(title: "URL") var url: URL

    static var parameterSummary: some ParameterSummary {
        Summary("Salva \(\.$url) in Bloom")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let container = try LocalLibrary.open()
            let inserted = try LinkStore.capture(url, into: container.mainContext)
            CaptureFailureInbox.resolve(url: url)
            let message: IntentDialog = inserted ? "Link salvato in Bloom" : "Link già presente in Bloom"
            return .result(dialog: message)
        } catch {
            CaptureFailureInbox.record(url: url, message: error.localizedDescription)
            throw needsToContinueInForegroundError("Link non salvato. Apri Bloom per riprovare.") {
                NotificationCenter.default.post(name: CaptureFailureInbox.ready, object: nil)
            }
        }
    }
}

struct BloomShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SaveLinkIntent(), phrases: ["Salva un link in \(.applicationName)"],
                    shortTitle: "Salva link", systemImageName: "tray.and.arrow.down")
    }
}

import Foundation
import SwiftData

struct StorageDiagnostics {
    let appInfo: [String: Any]
    let error: Error

    var report: String {
        let failure = error as NSError
        return """
        Bloom — diagnostica archivio privato v2
        Versione: \(appInfo["CFBundleShortVersionString"] as? String ?? "?") (\(appInfo["CFBundleVersion"] as? String ?? "?"))
        Commit: \(appInfo["BloomBuildCommit"] as? String ?? "non disponibile")
        Sistema: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Bundle app: \(appInfo["CFBundleIdentifier"] as? String ?? "assente")
        Archivio: Application Support privato di Bloom (SwiftData)
        App Groups: non richiesti
        Errore (dominio/codice): \(failure.domain) / \(failure.code)
        Il report non contiene contenuti salvati, percorsi locali, UDID o profili.
        """
    }
}

@MainActor
struct StorageAttempt {
    let result: Result<ModelContainer, Error>
    static func load() -> StorageAttempt {
        StorageAttempt(result: Result { try LocalLibrary.open() })
    }
}

import Foundation
import SwiftData

struct StorageDiagnostics {
    enum Stage: String {
        case configuration = "Configurazione App Group"
        case container = "Risoluzione container condiviso"
        case database = "Apertura database SwiftData"
        case ready = "Archivio aperto"
    }

    let appInfo: [String: Any]
    let extensionInfo: [String: Any]?
    let stage: Stage
    let error: Error?

    var report: String {
        let failure: String
        if let error {
            let code = error as NSError
            // Avoid error descriptions and userInfo: they can contain local paths or content.
            failure = "\(code.domain) / \(code.code)"
        } else { failure = "nessuno" }
        let group = appInfo["BloomAppGroup"] as? String ?? "assente"
        let extensionGroup = extensionInfo?["BloomAppGroup"] as? String ?? "non rilevato"
        let containerResult: String
        switch stage {
        case .configuration: containerResult = "non tentata: configurazione mancante o non risolta"
        case .container: containerResult = "nessun URL restituito da iOS"
        case .database, .ready: containerResult = "URL restituito da iOS; non prova gli entitlement dell’estensione"
        }
        return """
        Bloom — diagnostica archivio v1
        Versione: \(appInfo["CFBundleShortVersionString"] as? String ?? "?") (\(appInfo["CFBundleVersion"] as? String ?? "?"))
        Commit: \(appInfo["BloomBuildCommit"] as? String ?? "non disponibile")
        Sistema: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Bundle app: \(appInfo["CFBundleIdentifier"] as? String ?? "assente")
        App Group richiesto: \(group)
        Estensione incorporata: \(extensionInfo == nil ? "non rilevata" : "rilevata")
        Bundle estensione: \(extensionInfo?["CFBundleIdentifier"] as? String ?? "non rilevato")
        App Group estensione: \(extensionGroup)
        Gruppi dichiarati coincidenti: \(extensionInfo == nil ? "non verificabile" : (group == extensionGroup ? "sì" : "no"))
        Fase raggiunta: \(stage.rawValue)
        Risoluzione container: \(containerResult)
        Errore (dominio/codice): \(failure)
        Entitlement effettivi della firma e autorizzazioni del profilo: non verificati.
        Il report non contiene URL salvati, percorsi locali, UDID o profili di firma.
        """
    }

    static func configuredGroup(in info: [String: Any]) -> String? {
        guard let group = info["BloomAppGroup"] as? String,
              !group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !group.contains("$(") else { return nil }
        return group
    }
}

@MainActor
struct StorageAttempt {
    let result: Result<ModelContainer, Error>
    let diagnostics: StorageDiagnostics

    static func load(bundle: Bundle = .main) -> StorageAttempt {
        let info = bundle.infoDictionary ?? [:]
        let extensions = (try? FileManager.default.contentsOfDirectory(
            at: bundle.builtInPlugInsURL ?? bundle.bundleURL.appendingPathComponent("PlugIns"),
            includingPropertiesForKeys: nil
        )) ?? []
        let extensionInfo = extensions.first(where: { $0.pathExtension == "appex" })
            .flatMap { Bundle(url: $0)?.infoDictionary }
        var stage = StorageDiagnostics.Stage.configuration
        do {
            guard let group = StorageDiagnostics.configuredGroup(in: info) else {
                throw CaptureError.appGroupUnavailable
            }
            stage = .container
            guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
                throw CaptureError.appGroupUnavailable
            }
            stage = .database
            let container = try LinkStore.container(at: root)
            return StorageAttempt(result: .success(container), diagnostics: StorageDiagnostics(
                appInfo: info, extensionInfo: extensionInfo, stage: .ready, error: nil))
        } catch {
            return StorageAttempt(result: .failure(error), diagnostics: StorageDiagnostics(
                appInfo: info, extensionInfo: extensionInfo, stage: stage, error: error))
        }
    }
}

import SwiftUI
import UIKit

struct StorageFailureView: View {
    let diagnostics: StorageDiagnostics
    let retry: () -> Void
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Archivio non disponibile", systemImage: "externaldrive.badge.exclamationmark")
                        .font(.headline)
                    Text(explanation)
                    Button("Riprova apertura") {
                        copied = false
                        retry()
                    }
                }
                Section("Report diagnostico") {
                    Text(diagnostics.report)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Button(copied ? "Report copiato" : "Copia report") {
                        UIPasteboard.general.string = diagnostics.report
                        copied = true
                    }
                    ShareLink("Condividi report", item: diagnostics.report)
                }
                Section {
                    Text("Nessun dato è stato cancellato. La diagnostica non modifica la firma né le autorizzazioni di iOS.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Diagnostica Bloom")
        }
    }

    private var explanation: String {
        switch diagnostics.stage {
        case .configuration:
            return "L’identificatore dell’archivio condiviso è assente o non risolto nella configurazione installata. Copia il report per verificare la build."
        case .container:
            return "iOS non ha restituito il container dell’App Group richiesto. La firma e il profilo devono autorizzare lo stesso gruppo per Bloom e l’estensione. Copia il report per continuare la verifica."
        case .database:
            return "iOS ha restituito il container, ma SwiftData non ha aperto il database. Copia il report prima di modificare o reinstallare l’app."
        case .ready:
            return "L’archivio risulta aperto. Riprova per aggiornare lo stato."
        }
    }
}

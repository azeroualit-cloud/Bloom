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
        "Bloom non ha potuto aprire il proprio archivio locale. Copia il report prima di modificare o reinstallare l’app. Gli App Groups non sono più necessari."
    }
}

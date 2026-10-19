import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              data.count <= LibraryBackup.maximumFileBytes else { throw BackupError.invalid }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
struct BackupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("backup.lastExport") private var lastExport = 0.0
    @State private var document: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var preview: LibraryBackup?
    @State private var busy = false
    @State private var operation: Task<Void, Never>?
    @State private var requestID = UUID()
    @State private var message: String?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Il backup include note, link, allegati, tag e Archivio. Bozze, anteprime e dati del browser sono esclusi.")
                    Text("Il file non è cifrato. Scegli un luogo sicuro dove conservarlo.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Esportazione") {
                    if lastExport > 0 {
                        LabeledContent("Ultimo backup esportato", value: Date(timeIntervalSince1970: lastExport).formatted(date: .abbreviated, time: .shortened))
                    } else { Text("Nessun backup esportato da questo dispositivo.").foregroundStyle(.secondary) }
                    Button("Esporta libreria", systemImage: "square.and.arrow.up", action: prepareExport)
                        .disabled(busy || preview != nil)
                }
                Section("Ripristino") {
                    Button("Importa backup", systemImage: "square.and.arrow.down") {
                        error = nil; message = nil; importing = true
                    }.disabled(busy || preview != nil)
                    Text("Aggiunge i contenuti mancanti. Quelli già presenti conservano titolo, testo, tag e stato.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if let preview {
                    Section("Anteprima del backup") {
                        LabeledContent("Creato", value: preview.createdAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Contenuti", value: "\(preview.items.count)")
                        LabeledContent("Tag", value: "\(preview.collections.count)")
                        LabeledContent("Archiviati", value: "\(preview.items.filter(\.archived).count)")
                        LabeledContent("Allegati", value: "\(preview.items.reduce(0) { $0 + ($1.data == nil ? 0 : 1) + ($1.noteFiles?.count ?? 0) })")
                        Button("Aggiungi alla libreria", action: restore).disabled(busy)
                        Button("Annulla anteprima", role: .cancel) { self.preview = nil }.disabled(busy)
                    }
                }
                if busy {
                    Section {
                        ProgressView("Preparazione backup…")
                        Button("Annulla operazione", role: .cancel, action: cancel)
                    }
                }
                if let error { Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) } }
                if let message { Section { Text(message).accessibilityAddTraits(.updatesFrequently) } }
                Section {
                    Text("Limiti: file 100 MB, contenuti 60 MB, 10.000 elementi e 2.000 tag. Nessuna esportazione parziale.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Backup locale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fine") { cancel(); dismiss() } } }
            .sheet(isPresented: $importing) {
                DocumentImportPicker { result in
                    importing = false
                    switch result {
                    case .success(let url): if let url { read(url) }
                    case .failure(let failure): error = failure.localizedDescription
                    }
                }
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                          defaultFilename: "Bloom-backup-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash)))") { result in
                document = nil
                switch result {
                case .success: lastExport = Date().timeIntervalSince1970; message = "Backup esportato."
                case .failure(let failure):
                    if (failure as NSError).code == NSUserCancelledError { message = "Esportazione annullata." }
                    else { error = failure.localizedDescription }
                }
            }
            .onDisappear { cancel() }
        }
    }

    private func cancel() {
        requestID = UUID()
        operation?.cancel()
        operation = nil
        busy = false
    }

    private func begin(_ work: @escaping @MainActor () async throws -> Void) {
        cancel()
        let id = requestID
        busy = true; message = nil; error = nil
        operation = Task {
            defer { if id == requestID { busy = false; operation = nil } }
            do { try await work() }
            catch is CancellationError { }
            catch { if id == requestID { self.error = error.localizedDescription } }
        }
    }

    private func prepareExport() {
        begin {
            await Task.yield()
            try Task.checkCancellation()
            let snapshot = try BackupStore.snapshot(from: context.container)
            let data = try await Task.detached(priority: .userInitiated) { try snapshot.encoded() }.value
            try Task.checkCancellation()
            document = BackupDocument(data: data)
            exporting = true
        }
    }

    private func read(_ url: URL) {
        begin {
            let backup = try await Task.detached(priority: .userInitiated) { try LibraryBackup.read(url) }.value
            try Task.checkCancellation()
            preview = backup
        }
    }

    private func restore() {
        guard let backup = preview else { return }
        begin {
            await Task.yield()
            try Task.checkCancellation()
            let result = try BackupStore.restore(backup, into: context.container)
            preview = nil
            message = "Importati: \(result.added). Già presenti: \(result.skipped). Nuovi tag: \(result.collectionsAdded)."
        }
    }
}

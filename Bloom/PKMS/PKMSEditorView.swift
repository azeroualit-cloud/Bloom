import SwiftUI
import UniformTypeIdentifiers

struct PKMSMarkdownFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let text = String(data: data, encoding: .utf8) else { throw DropboxFailure.unsupportedText }
        self.text = text
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}

@MainActor
struct PKMSEditorView: View {
    @ObservedObject var store: PKMSStore
    let entry: DropboxEntry
    @Environment(\.scenePhase) private var scenePhase
    @State private var searching = false
    @State private var query = ""
    @State private var conflict = false
    @State private var exporting = false
    @State private var history = false
    @State private var exportError: String?
    private var document: PKMSDocument? { store.documents[entry.identity] }
    var body: some View {
        VStack(spacing: 0) {
            if searching {
                TextField("Cerca nel documento", text: $query).textFieldStyle(.roundedBorder).padding(.horizontal, 16).padding(.vertical, 8)
                    .accessibilityIdentifier("pkms-search-document")
            }
            if let document {
                if let storageError = store.storageError {
                    statusRow(storageError, symbol: "exclamationmark.triangle") { store.retryLocalSave() }
                } else if document.remoteDeleted {
                    statusRow("File non più nella cartella Dropbox · copia locale conservata", symbol: "exclamationmark.triangle") { exporting = true }
                } else if document.hasConflict {
                    statusRow("Modifica anche su Dropbox · confronta le versioni", symbol: "exclamationmark.triangle") { conflict = true }
                } else if let error = store.error {
                    statusRow(error, symbol: "icloud.slash") { Task { await store.sync() } }
                }
                LiveMarkdownEditor(text: Binding(get: { store.documents[entry.identity]?.text ?? "" },
                                                set: { store.update(id: entry.identity, text: $0) }), query: query)
                HStack(spacing: 6) {
                    Image(systemName: store.storageError != nil ? "exclamationmark.triangle" : document.dirty ? "icloud.and.arrow.up" : "checkmark")
                    Text(saveStatus(document)).font(.caption)
                    Spacer()
                }.foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 6)
            } else if store.loading.contains(entry.identity) {
                Spacer(); ProgressView("Apertura documento…"); Spacer()
            } else {
                ContentUnavailableView("Documento non disponibile offline", systemImage: "doc.text", description: Text(store.error ?? "Aprilo con una connessione per conservarne una copia sul dispositivo."))
                Button("Riprova apertura") { Task { await store.open(entry) } }.padding()
            }
        }
        .background(Color.bloomBackground)
        .navigationTitle(entry.title).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { searching.toggle(); if !searching { query = "" } } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("Cerca nel documento")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Sincronizza ora", systemImage: "arrow.triangle.2.circlepath") { Task { await store.sync() } }.disabled(store.syncing || !store.connected)
                    Button("Versioni locali", systemImage: "clock.arrow.circlepath") { history = true }.disabled(document == nil)
                    Button("Esporta Markdown", systemImage: "square.and.arrow.up") { exporting = true }.disabled(document == nil)
                    if document?.hasConflict == true { Button("Confronta versioni") { conflict = true } }
                } label: { Image(systemName: "ellipsis") }.accessibilityLabel("Azioni documento")
            }
        }
        .task { await store.open(entry) }
        .onDisappear { store.scheduleSync() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.sync() } } }
        .sheet(isPresented: $history) { PKMSHistoryView(store: store, id: entry.identity) }
        .sheet(isPresented: $conflict) { PKMSConflictView(store: store, id: entry.identity) }
        .fileExporter(isPresented: $exporting, document: PKMSMarkdownFile(text: document?.text ?? ""), contentType: .plainText,
                      defaultFilename: entry.title + ".md") { result in if case .failure(let error) = result { exportError = error.localizedDescription } }
        .alert("Esportazione non riuscita", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("Chiudi", role: .cancel) { }
        } message: { Text(exportError ?? "") }
    }
    private func saveStatus(_ document: PKMSDocument) -> String {
        if store.storageError != nil { return "Modifiche in memoria · salvataggio locale da riprovare" }
        if document.hasConflict { return "Salvato sul dispositivo · sincronizzazione sospesa" }
        if document.dirty { return store.syncing ? "Salvato sul dispositivo · sincronizzazione…" : "Salvato sul dispositivo · in attesa di Dropbox" }
        return "Salvato su Dropbox"
    }
    private func statusRow(_ text: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(text, systemImage: symbol).font(.caption).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 16)
        }.background(Color.bloomSurface)
    }
}

@MainActor
private struct PKMSConflictView: View {
    @ObservedObject var store: PKMSStore
    let id: String
    @Environment(\.dismiss) private var dismiss
    @State private var confirmLocal = false
    var body: some View {
        NavigationStack {
            List {
                Section { Text("Entrambe le versioni sono conservate. La scelta salva anche una copia di recupero sul dispositivo.") }
                Section("Questo dispositivo") { Text(store.documents[id]?.text ?? "").textSelection(.enabled) }
                Section("Dropbox") { Text(store.documents[id]?.conflictText ?? "Versione remota non disponibile").textSelection(.enabled) }
                if store.documents[id]?.conflictRevision != nil {
                    Button("Mantieni la versione del dispositivo") { confirmLocal = true }
                    Button("Usa la versione Dropbox") { store.resolve(id: id, keepLocal: false); if store.documents[id]?.hasConflict == false { dismiss() } }
                }
            }.bloomCanvas().navigationTitle("Confronta versioni").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Decidi dopo") { dismiss() } } }
                .confirmationDialog("Sostituire la versione Dropbox con quella del dispositivo?", isPresented: $confirmLocal, titleVisibility: .visible) {
                    Button("Mantieni versione del dispositivo") { store.resolve(id: id, keepLocal: true); if store.documents[id]?.hasConflict == false { dismiss() } }
                }
        }
    }
}

struct PKMSRecoveryView: View {
    let document: PKMSDocument
    var body: some View {
        ScrollView { Text(document.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(20) }
            .background(Color.bloomBackground).navigationTitle((document.path as NSString).lastPathComponent)
            .toolbar { ShareLink(item: document.text) { Label("Condividi copia locale", systemImage: "square.and.arrow.up") } }
    }
}

@MainActor
private struct PKMSHistoryView: View {
    @ObservedObject var store: PKMSStore
    let id: String
    @Environment(\.dismiss) private var dismiss
    @State private var versions: [PKMSDocument] = []
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                if let error { Text(error).foregroundStyle(.red) }
                if versions.isEmpty && error == nil {
                    ContentUnavailableView("Nessuna versione precedente", systemImage: "clock", description: Text("Le copie vengono conservate prima delle modifiche e delle scelte sui conflitti."))
                }
                ForEach(Array(versions.enumerated()), id: \.offset) { _, version in
                    NavigationLink {
                        ScrollView { Text(version.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(20) }
                            .bloomCanvas().navigationTitle("Versione locale")
                            .toolbar { ShareLink(item: version.text) { Label("Condividi versione", systemImage: "square.and.arrow.up") } }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(version.modifiedAt.formatted(date: .abbreviated, time: .standard))
                            Text("\(version.text.count) caratteri").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.bloomCanvas().navigationTitle("Versioni locali").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
                .task {
                    do { versions = try store.recoveryVersions(id: id) }
                    catch { self.error = error.localizedDescription }
                }
        }
    }
}

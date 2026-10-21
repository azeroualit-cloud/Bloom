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
    @State private var editing = false
    @State private var focused = false
    @State private var query = ""
    @State private var conflict = false
    @State private var exporting = false
    @State private var history = false
    @State private var exportError: String?
    @State private var attemptedOpening = false
    private var document: PKMSDocument? { store.documents[entry.identity] }
    private var openingFailed: Bool { attemptedOpening && document == nil && !store.loading.contains(entry.identity) }
    var body: some View {
        presentedEditor
            .alert("Esportazione non riuscita", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("Chiudi", role: .cancel) { }
            } message: { Text(exportError ?? "") }
    }
    private var presentedEditor: some View {
        activeEditor
            .sheet(isPresented: $history) { PKMSHistoryView(store: store, id: entry.identity) }
            .sheet(isPresented: $conflict) { PKMSConflictView(store: store, id: entry.identity) }
            .fileExporter(isPresented: $exporting, document: PKMSMarkdownFile(text: document?.text ?? ""), contentType: .plainText,
                          defaultFilename: entry.title + ".md") { result in
                if case .failure(let error) = result { exportError = error.localizedDescription }
            }
    }
    private var activeEditor: some View {
        editorContent
            .background(Color.bloomBackground)
            .navigationTitle(entry.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { editorToolbar }
            .toolbarBackground(Color.bloomBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar(focused ? .hidden : .visible, for: .tabBar)
            .task { await store.open(entry); attemptedOpening = true }
            .onDisappear { store.scheduleSync() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.sync() } } }
            .modifier(PKMSEditorFeedback(searching: searching, openingFailed: openingFailed, dirty: document?.dirty))
    }
    private var editorContent: some View {
        VStack(spacing: 0) {
            if searching {
                TextField("Cerca nel documento", text: $query).textFieldStyle(.roundedBorder).padding(.horizontal, 16).padding(.vertical, 8)
                    .accessibilityIdentifier("pkms-search-document")
            }
            if let document {
                documentContent(document)
            } else if !attemptedOpening || store.loading.contains(entry.identity) {
                Spacer(); ProgressView("Apertura documento…"); Spacer()
            } else {
                ContentUnavailableView(store.connected ? "Apertura non riuscita" : "Documento non disponibile offline", systemImage: "doc.text", description: Text(store.error ?? "Aprilo con una connessione per conservarne una copia sul dispositivo."))
                Button("Riprova apertura") { Task { await store.open(entry) } }.padding()
            }
        }
    }
    @ViewBuilder
    private func documentContent(_ document: PKMSDocument) -> some View {
        if let storageError = store.storageError {
            statusRow(storageError, symbol: "exclamationmark.triangle") { store.retryLocalSave() }
        } else if document.remoteDeleted {
            statusRow("File non più nella cartella Dropbox · copia locale conservata", symbol: "exclamationmark.triangle") { exporting = true }
        } else if document.hasConflict {
            statusRow("Modifica anche su Dropbox · confronta le versioni", symbol: "exclamationmark.triangle") { conflict = true }
        } else if let error = store.error {
            statusRow(error, symbol: "icloud.slash") { Task { await store.sync() } }
        }
        if editing {
            LiveMarkdownEditor(text: Binding(get: { store.documents[entry.identity]?.text ?? "" },
                                            set: { store.update(id: entry.identity, text: $0) }), query: query, focused: $focused)
                .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    MarkdownDocumentView(text: document.text, query: query)
                        .padding(16).padding(.bottom, 24).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
                }.accessibilityIdentifier("pkms-reader")
                    .onChange(of: query) { _, value in
                        if let index = MarkdownBlock.firstMatch(in: document.text, query: value) { proxy.scrollTo(index, anchor: .top) }
                    }
            }
        }
    }
    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text(entry.title).font(.headline).lineLimit(1)
                if let document {
                    Text((editing ? "Markdown · " : "") + compactSaveStatus(document))
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        .accessibilityLabel(saveStatus(document)).accessibilityIdentifier("pkms-save-status")
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(editing ? "Leggi" : "Scrivi", systemImage: editing ? "doc.richtext" : "square.and.pencil") {
                editing.toggle(); if !editing { focused = false }
            }.labelStyle(.titleOnly).disabled(document == nil).accessibilityIdentifier("pkms-toggle-edit")
                .accessibilityHint(editing ? "Mostra il documento formattato" : "Modifica il sorgente Markdown; le modifiche sono salvate automaticamente")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Cerca nel documento", systemImage: "magnifyingglass") { searching.toggle(); if !searching { query = "" } }
                Button("Sincronizza ora", systemImage: "arrow.triangle.2.circlepath") { Task { await store.sync() } }.disabled(store.syncing || !store.connected)
                Button("Versioni locali", systemImage: "clock.arrow.circlepath") { history = true }.disabled(document == nil)
                Button("Esporta Markdown", systemImage: "square.and.arrow.up") { exporting = true }.disabled(document == nil)
                if document?.hasConflict == true { Button("Confronta versioni") { conflict = true } }
            } label: { Image(systemName: "ellipsis") }.accessibilityLabel("Azioni documento")
        }
    }
    private func compactSaveStatus(_ document: PKMSDocument) -> String {
        if store.storageError != nil { return "Salvataggio da riprovare" }
        if document.remoteDeleted { return "Copia locale" }
        if document.hasConflict { return "Confronta versioni" }
        if document.dirty { return store.syncing ? "Sincronizzazione…" : "Salvato sul dispositivo" }
        if store.error != nil { return "Sincronizzazione da riprovare" }
        if !store.connected { return "Salvato · offline" }
        return store.syncing ? "Verifica Dropbox…" : "Salvato su Dropbox"
    }
    private func saveStatus(_ document: PKMSDocument) -> String {
        if store.storageError != nil { return "Modifiche in memoria · salvataggio locale da riprovare" }
        if document.remoteDeleted { return "Copia locale · file rimosso da Dropbox" }
        if document.hasConflict { return "Salvato sul dispositivo · sincronizzazione sospesa" }
        if document.dirty { return store.syncing ? "Salvato sul dispositivo · sincronizzazione…" : "Salvato sul dispositivo · in attesa di Dropbox" }
        if store.error != nil { return "Copia locale disponibile · sincronizzazione non riuscita" }
        if !store.connected { return "Offline · salvato sul dispositivo" }
        if store.syncing { return "Verifica delle modifiche su Dropbox…" }
        return "Sincronizzato con Dropbox"
    }
    private func statusRow(_ text: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(text, systemImage: symbol).font(.caption).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 16)
        }.background(Color.bloomSurface)
    }
}

/// Keep feedback state outside the document/export view's generic modifier chain.
private struct PKMSEditorFeedback: ViewModifier {
    let searching: Bool
    let openingFailed: Bool
    let dirty: Bool?
    @State private var saves = 0
    @State private var failures = 0
    func body(content: Content) -> some View {
        content
            .onChange(of: dirty) { old, new in
                if old == true && new == false { saves += 1 }
            }
            .onChange(of: openingFailed) { _, failed in
                if failed { failures += 1 }
            }
            .sensoryFeedback(.selection, trigger: searching)
            .sensoryFeedback(.success, trigger: saves)
            .sensoryFeedback(.error, trigger: failures)
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

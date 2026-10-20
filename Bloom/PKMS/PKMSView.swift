import SwiftUI

@MainActor
struct PKMSView: View {
    @ObservedObject var store: PKMSStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var expanded = Set<String>()
    @State private var search = ""
    @State private var settings = false
    @State private var choosingRoot = false
    private struct TreeRow: Identifiable {
        let entry: DropboxEntry; let depth: Int
        var id: String { entry.identity }
    }
    private var rows: [TreeRow] {
        let entries = store.index.entries
        if !search.isEmpty {
            return entries.filter { !$0.isFolder && $0.title.localizedStandardContains(search) }
                .sorted { $0.pathLower < $1.pathLower }.map { TreeRow(entry: $0, depth: 0) }
        }
        let byParent = Dictionary(grouping: entries, by: \.parent)
        func children(_ path: String, depth: Int) -> [TreeRow] {
            (byParent[path] ?? []).sorted {
                if $0.isFolder != $1.isFolder { return $0.isFolder }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }.flatMap { entry -> [TreeRow] in
                [TreeRow(entry: entry, depth: depth)] + (entry.isFolder && expanded.contains(entry.pathLower) ? children(entry.pathLower, depth: depth + 1) : [])
            }
        }
        return children(store.index.root ?? "", depth: 0)
    }
    var body: some View {
        NavigationStack {
            List {
                if let storageError = store.storageError {
                    Section { Text(storageError).foregroundStyle(.red); Button("Riprova salvataggio locale") { store.retryLocalSave() } }
                }
                if store.index.root == nil {
                    Section {
                        ContentUnavailableView("Il tuo PKMS", systemImage: "folder", description: Text("Collega Dropbox e scegli la cartella delle tue note Markdown. I file rimangono su Dropbox."))
                        Button(store.connected ? "Scegli cartella Dropbox" : "Collega Dropbox") {
                            if store.connected { choosingRoot = true } else { settings = true }
                        }.accessibilityIdentifier("pkms-connect")
                    }
                } else {
                    if let error = store.error {
                        Section {
                            Text(error).font(.subheadline)
                            Button(store.connected ? "Riprova sincronizzazione" : "Ricollega Dropbox") {
                                if store.connected { Task { await store.sync() } } else { settings = true }
                            }
                        }
                    }
                    if rows.isEmpty && !store.syncing {
                        ContentUnavailableView(search.isEmpty ? "Nessuna nota Markdown" : "Nessun risultato", systemImage: "doc.text", description: Text("I documenti .md e .markdown compaiono nelle loro cartelle."))
                    }
                    ForEach(rows) { row in
                        if row.entry.isFolder {
                            Button {
                                if !expanded.insert(row.entry.pathLower).inserted { expanded.remove(row.entry.pathLower) }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: expanded.contains(row.entry.pathLower) ? "chevron.down" : "chevron.right").font(.caption).frame(width: 16).foregroundStyle(.secondary)
                                    Text(row.entry.title).foregroundStyle(Color.bloomText).lineLimit(2)
                                    Spacer(minLength: 0)
                                }.padding(.leading, CGFloat(min(row.depth, 12)) * 16).frame(minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityValue(expanded.contains(row.entry.pathLower) ? "Espansa" : "Chiusa")
                        } else {
                            NavigationLink {
                                PKMSEditorView(store: store, entry: row.entry)
                            } label: {
                                HStack {
                                    Text(row.entry.title).lineLimit(2)
                                    Spacer(minLength: 0)
                                    if store.documents[row.id]?.hasConflict == true { Image(systemName: "exclamationmark.triangle").accessibilityLabel("Conflitto") }
                                    else if store.documents[row.id]?.dirty == true { Image(systemName: "icloud.and.arrow.up").accessibilityLabel("Modifiche in attesa") }
                                }.padding(.leading, CGFloat(min(row.depth, 12)) * 16 + 24).frame(minHeight: 44)
                            }.accessibilityIdentifier("pkms-note-\(row.entry.title)")
                        }
                    }.listRowSeparator(.hidden).listRowBackground(Color.bloomBackground)
                    let recovered = store.documents.values.filter { $0.remoteDeleted }
                    if !recovered.isEmpty {
                        Section("Copie locali · file non più su Dropbox") {
                            ForEach(recovered.sorted { $0.path < $1.path }, id: \.id) { document in
                                NavigationLink((document.path as NSString).lastPathComponent) {
                                    PKMSRecoveryView(document: document)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain).bloomCanvas()
            .navigationTitle("PKMS").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Cerca documenti")
            .refreshable { await store.sync() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await store.sync() } } label: {
                        if store.syncing { ProgressView() } else { Image(systemName: "arrow.triangle.2.circlepath") }
                    }.disabled(!store.connected || store.index.root == nil || store.syncing).accessibilityLabel("Sincronizza PKMS")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { settings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Impostazioni PKMS")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if store.index.root != nil {
                    HStack(spacing: 8) {
                        Image(systemName: store.connected ? "externaldrive.badge.icloud" : "icloud.slash")
                        Text(status).font(.caption)
                        Spacer()
                    }.foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 8).background(Color.bloomBackground)
                }
            }
            .sheet(isPresented: $settings) { PKMSSettingsView(store: store) }
            .sheet(isPresented: $choosingRoot) { DropboxFolderPicker { path in Task { await store.selectRoot(path) } } }
            .task {
                await store.refreshConnection()
                while !Task.isCancelled {
                    await store.sync()
                    do { try await Task.sleep(for: .seconds(45)) } catch { return }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await store.refreshConnection(); await store.sync() } }
            }
        }
    }
    private var status: String {
        if store.syncing { return "Sincronizzazione…" }
        if store.conflictCount > 0 { return "\(store.conflictCount) documenti da verificare" }
        if store.pendingCount > 0 { return "\(store.pendingCount) modifiche salvate sul dispositivo, in attesa" }
        if !store.connected { return "Offline · copie locali disponibili" }
        if let date = store.index.lastSync { return "Dropbox · aggiornato \(date.formatted(date: .omitted, time: .shortened))" }
        return "Dropbox · in attesa di sincronizzazione"
    }
}

@MainActor
struct PKMSSettingsView: View {
    @ObservedObject var store: PKMSStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pkms.dropbox.appKey") private var appKey = ""
    @State private var auth = DropboxAuthentication()
    @State private var connecting = false
    @State private var choosingRoot = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Dropbox") {
                    Text(store.connected ? "Account collegato" : "Account non collegato")
                    if !store.connected {
                        TextField("Dropbox App key pubblica", text: $appKey).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button(connecting ? "Collegamento…" : "Collega Dropbox") { connect() }.disabled(connecting || appKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button("Scegli cartella PKMS") { choosingRoot = true }.disabled(store.syncing || store.pendingCount > 0)
                        Button("Scollega Dropbox", role: .destructive) { Task { await store.disconnect() } }.disabled(store.syncing)
                    }
                    if let path = store.index.root { Text(path.isEmpty ? "/" : path).font(.caption).foregroundStyle(.secondary) }
                    if store.pendingCount > 0 { Text("Le modifiche locali devono essere sincronizzate prima di cambiare cartella.").font(.caption) }
                    Text("Scollegare l’account conserva documenti e modifiche locali. Per questa cartella sarà possibile ricollegare soltanto lo stesso account.").font(.caption)
                }
                if !store.connected {
                    Section("Configurazione iniziale") {
                        Link("Dropbox App Console", destination: URL(string: "https://www.dropbox.com/developers/apps")!)
                        Text("Crea una app Scoped access / Full Dropbox. Abilita files.metadata.read, files.content.read e files.content.write. Registra questo Redirect URI:")
                        Text(DropboxClient.redirect).font(.caption.monospaced()).textSelection(.enabled)
                        Text("Inserisci solo l’App key pubblica. Bloom usa OAuth con PKCE: nessuna password o App secret nell’app.").font(.caption)
                    }
                }
                Section("Documenti") {
                    Text("Bloom aggiorna i file Markdown originali. La Libreria di immagini e video rimane separata e locale.")
                    Text("I documenti aperti vengono conservati offline sul dispositivo. I conflitti richiedono una scelta esplicita e mantengono una copia di recupero.")
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }.bloomCanvas().navigationTitle("PKMS e Dropbox").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
                .sheet(isPresented: $choosingRoot) {
                    DropboxFolderPicker { path in Task { await store.selectRoot(path) } }
                }
        }
    }
    private func connect() {
        connecting = true; error = nil
        Task {
            defer { connecting = false }
            do {
                let account = try await auth.connect(appKey: appKey, expectedAccount: store.accountID)
                await store.didConnect(account: account)
                if store.index.root == nil { choosingRoot = true }
            } catch { self.error = error.localizedDescription }
        }
    }
}

@MainActor
struct DropboxFolderPicker: View {
    @Environment(\.dismiss) private var dismiss
    let choose: (String) -> Void
    @State private var path = ""
    @State private var folders: [DropboxEntry] = []
    @State private var loading = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(path.isEmpty ? "Dropbox" : path).font(.caption).foregroundStyle(.secondary)
                    Button("Usa questa cartella") { choose(path); dismiss() }.disabled(loading || error != nil)
                }
                if !path.isEmpty { Button("Cartella superiore", systemImage: "chevron.left") { let parent = (path as NSString).deletingLastPathComponent; path = parent == "/" ? "" : parent } }
                if loading { ProgressView("Caricamento cartelle…") }
                if let error { Text(error); Button("Riprova") { Task { await load() } } }
                ForEach(folders, id: \.identity) { folder in
                    Button { path = folder.pathLower } label: { Label(folder.name, systemImage: "folder") }
                }
            }.bloomCanvas().navigationTitle("Cartella PKMS").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } } }
                .task(id: path) { await load() }
        }
    }
    private func load() async {
        let requested = path
        loading = true; error = nil
        do {
            var cursor: String?, all: [DropboxEntry] = [], more = true
            while more {
                let page = try await DropboxClient.shared.list(path: requested, recursive: false, cursor: cursor)
                try Task.checkCancellation()
                all += page.entries.filter(\.isFolder); cursor = page.cursor; more = page.hasMore
            }
            guard requested == path else { return }
            folders = all.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            loading = false
        } catch {
            guard requested == path, !Task.isCancelled else { return }
            folders = []; loading = false; self.error = error.localizedDescription
        }
    }
}

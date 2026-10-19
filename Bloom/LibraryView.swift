import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

@MainActor
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CapturedLink.capturedAt, order: .reverse) private var links: [CapturedLink]
    @Query(sort: \LinkCollection.name) private var collections: [LinkCollection]
    @State private var search = ""
    @State private var archived = false
    @State private var collectionFilter: CollectionFilter = .all
    @State private var showingAdd = false
    @State private var showingText = false
    @State private var showingFiles = false
    @State private var showingPhotos = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var importer = ContentImportController()
    @State private var showingGuide = false
    @State private var showingCollections = false
    @State private var showingBackup = false
    @State private var notice: String?
    @State private var error: String?

    private var visibleLinks: [CapturedLink] {
        links.filter { LibraryFilter.matches($0, search: search, archived: archived, collection: collectionFilter) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Stato contenuti", selection: $archived) {
                        Text("Libreria").tag(false)
                        Text("Archivio").tag(true)
                    }.pickerStyle(.segmented)
                    if collectionFilter != .all {
                        LabeledContent("Raccolta", value: selectedCollectionName)
                    }
                    if let notice { Text(notice).foregroundStyle(.secondary) }
                    if let importError = importer.error {
                        Label(importError, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                        if importer.canRetry { Button("Riprova importazione") { importer.retry(into: context) } }
                        Button("Chiudi errore") { importer.error = nil; importer.cancel() }
                    }
                }
                if visibleLinks.isEmpty {
                    ContentUnavailableView(emptyTitle, systemImage: "tray",
                        description: Text(emptyDescription))
                }
                ForEach(visibleLinks) { link in
                    NavigationLink { ContentViewer(item: link) } label: { LibraryRow(link: link) }
                        .swipeActions(allowsFullSwipe: false) {
                            Button(archived ? "Ripristina" : "Archivia", systemImage: "archivebox") {
                                do {
                                    try LinkStore.setArchived(!link.isArchived, for: link, in: context)
                                    notice = archived ? "Contenuto ripristinato" : "Contenuto spostato in Archivio"
                                } catch { self.error = error.localizedDescription }
                            }.tint(.orange)
                        }
                }
            }
            .navigationTitle("Bloom")
            .searchable(text: $search, prompt: "Cerca nei contenuti")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Filtra raccolta", selection: $collectionFilter) {
                            Text("Tutte").tag(CollectionFilter.all)
                            Text("Senza raccolta").tag(CollectionFilter.unfiled)
                            ForEach(collections) { Text($0.name).tag(CollectionFilter.collection($0.id)) }
                        }
                        Divider()
                        Button("Gestisci raccolte", systemImage: "folder") { showingCollections = true }
                        Button("Backup locale", systemImage: "externaldrive") { showingBackup = true }
                        Button("Come salvare dai social", systemImage: "square.and.arrow.up") { showingGuide = true }
                    } label: { Label("Raccolte e guida", systemImage: "folder") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Link", systemImage: "link") { showingAdd = true }
                        Button("Testo", systemImage: "text.alignleft") { showingText = true }
                        Button("Foto", systemImage: "photo") { showingPhotos = true }
                        Button("File (max 25 MB)", systemImage: "doc") { showingFiles = true }
                    } label: { Label("Aggiungi contenuto", systemImage: "plus") }
                        .disabled(importer.isImporting)
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddLinkView { inserted in
                    if inserted { archived = false; collectionFilter = .all; search = "" }
                    notice = inserted ? "Link salvato" : "Link già presente. Controlla anche Archivio."
                }
            }
            .sheet(isPresented: $showingText) {
                AddTextView { inserted in
                    if inserted { archived = false; collectionFilter = .all; search = "" }
                    notice = inserted ? "Testo salvato" : "Testo già presente. Controlla anche Archivio."
                }
            }
            .sheet(isPresented: $showingFiles) {
                DocumentImportPicker { result in
                    showingFiles = false
                    switch result {
                    case .success(let url):
                        if let url { importer.importFile(url, into: context) }
                    case .failure(let failure): importer.error = failure.localizedDescription
                    }
                }
            }
            .photosPicker(isPresented: $showingPhotos, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { _, item in
                if let item { importer.importPhoto(item, into: context); selectedPhoto = nil }
            }
            .onChange(of: importer.completionID) { _, _ in
                if let message = importer.message { notice = message; archived = false; collectionFilter = .all; search = "" }
            }
            .safeAreaInset(edge: .bottom) {
                if importer.isImporting {
                    HStack {
                        ProgressView("Importazione: \(importer.importingName ?? "contenuto")")
                        Spacer()
                        Button("Annulla") { importer.cancel() }
                    }.padding().background(.regularMaterial)
                }
            }
            .sheet(isPresented: $showingGuide) { CaptureGuideView() }
            .sheet(isPresented: $showingCollections) { CollectionsView() }
            .sheet(isPresented: $showingBackup) { BackupView() }
            .onChange(of: collections.map(\.id)) { _, ids in
                if case .collection(let id) = collectionFilter, !ids.contains(id) { collectionFilter = .all }
            }
            .alert("Operazione non riuscita", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Chiudi", role: .cancel) { }
            } message: { Text(error ?? "") }
        }
    }

    private var selectedCollectionName: String {
        switch collectionFilter {
        case .all: return "Tutte"
        case .unfiled: return "Senza raccolta"
        case .collection(let id): return collections.first { $0.id == id }?.name ?? "Raccolta"
        }
    }
    private var emptyTitle: String {
        if !search.isEmpty || collectionFilter != .all { return "Nessun risultato" }
        return archived ? "Archivio vuoto" : "Nessun contenuto in libreria"
    }
    private var emptyDescription: String {
        if !search.isEmpty || collectionFilter != .all { return "Prova un’altra ricerca o cambia raccolta." }
        return archived ? "I contenuti archiviati restano qui e puoi ripristinarli."
            : "Aggiungi link, testi, foto o file con +."
    }
}

private struct LibraryRow: View {
    let link: CapturedLink
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(link.displayTitle, systemImage: link.kind.symbol).font(.headline).lineLimit(2)
            if link.kind == .link {
                Text(link.urlString).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            } else if link.kind == .text {
                Text(link.textContent ?? "").font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            } else if let count = link.attachmentByteCount {
                Text(ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let notes = link.notes { Text(notes).font(.subheadline).lineLimit(2) }
            if let collection = link.collection { Label(collection.name, systemImage: "folder").font(.caption) }
            Text(link.capturedAt, style: .date).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}

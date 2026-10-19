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
    @State private var kindFilter: ContentKind?
    @State private var selecting = false
    @State private var selection = Set<UUID>()
    @State private var titles = LinkTitleController()
    @State private var importKind: ContentKind?
    @State private var showingImportOptions = false
    @State private var importCollectionID: UUID?
    @State private var continueImport = false
    @State private var savedID: UUID?
    @State private var pendingOpenID: UUID?
    @State private var openedItem: CapturedLink?
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
        links.filter { LibraryFilter.matches($0, search: search, archived: archived, collection: collectionFilter, kind: kindFilter) }
    }

    var body: some View {
        NavigationStack { presentedLibrary }
    }

    private var libraryContent: some View {
        libraryList
            .environment(\.editMode, .constant(selecting ? .active : .inactive))
            .navigationTitle("Bloom")
            .navigationDestination(item: $openedItem) { ContentViewer(item: $0) }
            .searchable(text: $search, prompt: "Cerca nei contenuti")
            .toolbar { libraryToolbar }
    }

    private var presentedLibrary: some View {
        libraryContent
            .sheet(isPresented: $showingAdd, onDismiss: openPending) {
                AddLinkView { receipt, openAfterSave in captured(receipt, openAfterSave: openAfterSave) }
            }
            .sheet(isPresented: $showingText, onDismiss: openPending) {
                AddTextView { receipt, openAfterSave in captured(receipt, openAfterSave: openAfterSave) }
            }
            .sheet(isPresented: $showingImportOptions, onDismiss: {
                guard continueImport else { return }
                continueImport = false
                if importKind == .image { showingPhotos = true } else { showingFiles = true }
            }) {
                ImportOptionsView(kind: importKind ?? .file) { id in
                    importCollectionID = id
                    continueImport = true
                }
            }
            .sheet(isPresented: $showingFiles) {
                DocumentImportPicker { result in
                    showingFiles = false
                    switch result {
                    case .success(let url):
                        if let url { importer.importFile(url, collectionID: importCollectionID, into: context) }
                    case .failure(let failure): importer.error = failure.localizedDescription
                    }
                }
            }
            .photosPicker(isPresented: $showingPhotos, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { _, item in
                if let item { importer.importPhoto(item, collectionID: importCollectionID, into: context); selectedPhoto = nil }
            }
            .onChange(of: importer.completionID) { _, _ in
                if let message = importer.message { notice = message; savedID = importer.savedID; resetFilters() }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if selecting { selectionActions }
                    if titles.isLoading {
                        HStack { ProgressView("Recupero titoli…"); Spacer(); Button("Annulla") { titles.cancel() } }.padding()
                    }
                    if importer.isImporting {
                        HStack {
                            ProgressView("Importazione: \(importer.importingName ?? "contenuto")")
                            Spacer()
                            Button("Annulla") { importer.cancel() }
                        }.padding()
                    }
                }.background(.regularMaterial)
            }
            .onChange(of: visibleLinks.map(\.id)) { _, ids in selection.formIntersection(Set(ids)) }
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

    private var libraryList: some View {
            List(selection: $selection) {
                Section {
                    Picker("Stato contenuti", selection: $archived) {
                        Text("Libreria").tag(false)
                        Text("Archivio").tag(true)
                    }.pickerStyle(.segmented)
                    if collectionFilter != .all {
                        LabeledContent("Raccolta", value: selectedCollectionName)
                    }
                    if let kindFilter { LabeledContent("Formato", value: kindFilter.label) }
                    Text("\(visibleLinks.count) contenuti").accessibilityIdentifier("library-count").font(.caption).foregroundStyle(.secondary)
                    if let notice { Text(notice).foregroundStyle(.secondary) }
                    if let savedID { Button("Apri contenuto salvato") { open(savedID) } }
                    if let message = titles.message { Text(message).font(.subheadline).foregroundStyle(.secondary) }
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
                        .tag(link.id)
                        .contextMenu {
                            if link.kind == .link && link.title == nil {
                                Button("Recupera titolo dal sito") { titles.start([link], in: context) }
                                    .disabled(titles.isLoading)
                            }
                        }
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
    }

    @ToolbarContentBuilder
    private var libraryToolbar: some ToolbarContent {

                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ContentFilterOptions(collection: $collectionFilter, kind: $kindFilter)
                        Divider()
                        Button("Gestisci raccolte", systemImage: "folder") { showingCollections = true }
                        Button("Backup locale", systemImage: "externaldrive") { showingBackup = true }
                        Button("Come salvare dai social", systemImage: "square.and.arrow.up") { showingGuide = true }
                    } label: { Label("Raccolte e guida", systemImage: "folder") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(selecting ? "Fine" : "Seleziona") { selecting.toggle(); selection.removeAll() }.accessibilityIdentifier("library-select")
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Link", systemImage: "link") { showingAdd = true }
                        Button("Testo", systemImage: "text.alignleft") { showingText = true }.accessibilityIdentifier("capture-text")
                        Button("Foto", systemImage: "photo") { importKind = .image; showingImportOptions = true }
                        Button("File (max 25 MB)", systemImage: "doc") { importKind = .file; showingImportOptions = true }
                    } label: { Label("Aggiungi contenuto", systemImage: "plus") }
                        .accessibilityIdentifier("capture-add")
                        .disabled(importer.isImporting || selecting)
                }

    }

    private func resetFilters() { archived = false; collectionFilter = .all; kindFilter = nil; search = "" }

    private func captured(_ receipt: CaptureReceipt, openAfterSave: Bool) {
        if receipt.inserted { resetFilters() }
        savedID = receipt.id
        notice = receipt.inserted ? "Contenuto salvato" : "Contenuto già presente: metadati conservati."
        if openAfterSave { pendingOpenID = receipt.id }
    }

    private func openPending() {
        if let id = pendingOpenID { pendingOpenID = nil; open(id) }
    }

    private func open(_ id: UUID) {
        do {
            guard let item = try context.fetch(FetchDescriptor<CapturedLink>(predicate: #Predicate { $0.id == id })).first else {
                throw LibraryError.selectionMissing
            }
            openedItem = item
        } catch { self.error = error.localizedDescription }
    }

    private var selectionActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(selection.count) selezionati").font(.subheadline)
                Spacer()
                Button("Seleziona visibili") { selection = Set(visibleLinks.map(\.id)) }.accessibilityIdentifier("bulk-select-all")
            }
            ViewThatFits(in: .horizontal) {
                HStack { bulkCollectionMenu; archiveSelection; titleSelection }
                VStack(alignment: .leading) { bulkCollectionMenu; archiveSelection; titleSelection }
            }
        }.padding()
    }

    private var bulkCollectionMenu: some View {
        Menu {
            Button("Senza raccolta") { bulk(.collection(nil)) }
            ForEach(collections) { collection in Button(collection.name) { bulk(.collection(collection.id)) } }
        } label: { Label("Raccolta", systemImage: "folder") }.disabled(selection.isEmpty)
    }
    private var archiveSelection: some View {
        Button(archived ? "Ripristina" : "Archivia", systemImage: "archivebox") { bulk(.archived(!archived)) }
            .accessibilityIdentifier("bulk-archive-action").disabled(selection.isEmpty)
    }
    private var titleSelection: some View {
        Button("Titoli (max 10)", systemImage: "text.magnifyingglass") {
            titles.start(links.filter { selection.contains($0.id) }, in: context)
        }.disabled(selection.isEmpty || titles.isLoading)
    }
    private func bulk(_ change: LinkStore.BulkChange) {
        do {
            let count = try LinkStore.apply(change, to: selection, in: context)
            notice = "Aggiornati \(count) contenuti."
            selection.removeAll()
        } catch { self.error = error.localizedDescription }
    }

    private var selectedCollectionName: String {
        switch collectionFilter {
        case .all: return "Tutte"
        case .unfiled: return "Senza raccolta"
        case .collection(let id): return collections.first { $0.id == id }?.name ?? "Raccolta"
        }
    }
    private var emptyTitle: String {
        if !search.isEmpty || collectionFilter != .all || kindFilter != nil { return "Nessun risultato" }
        return archived ? "Archivio vuoto" : "Nessun contenuto in libreria"
    }
    private var emptyDescription: String {
        if !search.isEmpty || collectionFilter != .all || kindFilter != nil { return "Prova un’altra ricerca o cambia raccolta." }
        return archived ? "I contenuti archiviati restano qui e puoi ripristinarli."
            : "Aggiungi link, testi, foto o file con +."
    }
}

private struct LibraryRow: View {
    let link: CapturedLink
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(link.displayTitle, systemImage: link.kind.symbol).font(.headline).lineLimit(2)
            if link.kind == .image {
                AttachmentThumbnail(item: link, maximumPixelSize: 384).frame(maxHeight: 140)
            }
            if link.kind == .link {
                Text(link.urlString).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            } else if link.kind == .text {
                Text(String((link.textContent ?? "").prefix(250))).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            } else if let count = link.attachmentByteCount {
                Text(ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let notes = link.notes { Text(String(notes.prefix(250))).font(.subheadline).lineLimit(2) }
            if let collection = link.collection { Label(collection.name, systemImage: "folder").font(.caption) }
            Text(link.capturedAt, style: .date).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}

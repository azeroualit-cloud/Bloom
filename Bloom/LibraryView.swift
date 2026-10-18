import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CapturedLink.capturedAt, order: .reverse) private var links: [CapturedLink]
    @Query(sort: \LinkCollection.name) private var collections: [LinkCollection]
    @State private var search = ""
    @State private var archived = false
    @State private var collectionFilter: CollectionFilter = .all
    @State private var showingAdd = false
    @State private var showingGuide = false
    @State private var showingCollections = false
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
                }
                if visibleLinks.isEmpty {
                    ContentUnavailableView(emptyTitle, systemImage: "tray",
                        description: Text(emptyDescription))
                }
                ForEach(visibleLinks) { link in
                    NavigationLink { LinkDetailView(link: link) } label: { LibraryRow(link: link) }
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
            .searchable(text: $search, prompt: "Titolo, link, note o raccolta")
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
                        Button("Come salvare dai social", systemImage: "square.and.arrow.up") { showingGuide = true }
                    } label: { Label("Raccolte e guida", systemImage: "folder") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Aggiungi link", systemImage: "plus") { showingAdd = true }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddLinkView { inserted in
                    if inserted { archived = false; collectionFilter = .all; search = "" }
                    notice = inserted ? "Link salvato" : "Link già presente. Controlla anche Archivio."
                }
            }
            .sheet(isPresented: $showingGuide) { CaptureGuideView() }
            .sheet(isPresented: $showingCollections) { CollectionsView() }
            .onChange(of: collections.map(\.id)) { _, ids in
                if case .collection(let id) = collectionFilter, !ids.contains(id) { collectionFilter = .all }
            }
            .alert("Operazione non riuscita", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { }
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
        return archived ? "Archivio vuoto" : "La tua libreria inizia qui"
    }
    private var emptyDescription: String {
        if !search.isEmpty || collectionFilter != .all { return "Prova un’altra ricerca o cambia raccolta." }
        return archived ? "I contenuti archiviati restano qui e puoi ripristinarli."
            : "Aggiungi un link con + oppure usa il comando Condividi dai social."
    }
}

private struct LibraryRow: View {
    let link: CapturedLink
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(link.title ?? URL(string: link.urlString)?.host ?? link.urlString).font(.headline)
            Text(link.urlString).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            if let notes = link.notes { Text(notes).font(.subheadline).lineLimit(2) }
            if let collection = link.collection { Label(collection.name, systemImage: "folder").font(.caption) }
            Text(link.capturedAt, style: .date).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}

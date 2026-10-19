import SwiftUI
import SwiftData

@MainActor
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CapturedLink.capturedAt, order: .reverse) private var items: [CapturedLink]
    @Query(sort: \LinkCollection.name) private var tags: [LinkCollection]
    @State private var search = ""
    @State private var archived = false
    @State private var filter: CollectionFilter = .all
    @State private var kind: ContentKind?
    @State private var sort = LibrarySort.newest
    @State private var selecting = false
    @State private var selection = Set<UUID>()
    @State private var allNotes = false
    @State private var revealed: UUID?
    @State private var deleting: CapturedLink?
    @State private var deletePrompt = false
    @State private var adding = false
    @State private var addingPhoto = false
    @State private var managingTags = false
    @State private var backup = false
    @State private var guide = false
    @State private var contentRoute: ArchiveContentRoute?
    @State private var opened: CapturedLink?
    @State private var savedID: UUID?
    @State private var notice: String?
    @State private var error: String?
    @State private var editingTags = false
    @State private var tagNote: CapturedLink?
    @State private var bulkTags = Set<UUID>()
    @State private var bulkMode = LinkStore.TagChange.add
    private struct ArchiveUndo { let ids: Set<UUID>; let wasArchived: Bool }
    @State private var archiveUndo: ArchiveUndo?

    private var visible: [CapturedLink] {
        let matchingTagIDs = Set(tags.filter { $0.name.localizedStandardContains(search) }.map(\.id))
        return sort.sort(items.filter { item in
            let matchesBase = LibraryFilter.matches(item, search: "", archived: archived, collection: filter, kind: kind)
            return matchesBase && (LibraryFilter.matches(item, search: search, archived: archived, collection: filter, kind: kind) || !item.tagIDs.isDisjoint(with: matchingTagIDs))
        })
    }
    private var showingTags: Bool { !allNotes && search.isEmpty && kind == nil && !selecting }
    private let categoryColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
    private let contentColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)

    var body: some View { NavigationStack { presentedLibrary } }
    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header.padding(.horizontal, 16)
                if showingTags {
                    let homeItems = visible
                    LazyVGrid(columns: categoryColumns, spacing: 20) {
                        category("Tutti", symbol: "square.grid.2x2", value: .all, members: homeItems)
                        category("Da specificare", symbol: "tag", value: .unfiled, members: homeItems.filter { $0.tagIDs.isEmpty })
                        ForEach(tags) { tag in
                            category(tag.name, symbol: "tag.fill", value: .collection(tag.id), members: homeItems.filter { $0.tagIDs.contains(tag.id) })
                        }
                    }.padding(.horizontal, 16).frame(maxWidth: 760).frame(maxWidth: .infinity)
                        .accessibilityIdentifier("category-grid")
                } else if visible.isEmpty {
                    ContentUnavailableView("Nessuna nota", systemImage: "note.text", description: Text("Aggiungi una nota o cambia i filtri."))
                } else {
                    LazyVGrid(columns: contentColumns, spacing: 0) { ForEach(visible) { item in card(item) } }
                        .accessibilityIdentifier("content-grid")
                }
            }.padding(.vertical, 16).frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(archived ? "Archivio" : showingTags ? "Bloom" : categoryTitle)
        .searchable(text: $search, prompt: "Cerca note, testi e tag")
        .navigationDestination(item: $opened) { ContentViewer(item: $0) }
        .navigationDestination(item: $contentRoute) { ArchiveContentDestination(route: $0) }
        .toolbar { toolbar }
        .onChange(of: filter) { _, _ in revealed = nil }
        .onChange(of: archived) { _, _ in revealed = nil }
    }
    private var categoryTitle: String {
        switch filter {
        case .all: return "Tutte le note"
        case .unfiled: return "Da specificare"
        case .collection(let id): return tags.first { $0.id == id }?.name ?? "Note"
        }
    }
    private func category(_ name: String, symbol: String, value: CollectionFilter, members: [CapturedLink]) -> some View {
        let cover = members.first { $0.kind == .image || ($0.previewImageData != nil && $0.previewSourceURL == $0.allLinks.first?.absoluteString) } ?? members.first
        return categoryButton(name, symbol: symbol, value: value, count: members.count, cover: cover)
    }
    private func categoryButton(_ name: String, symbol: String, value: CollectionFilter, count: Int, cover: CapturedLink?) -> some View {
        Button { filter = value; allNotes = true; revealed = nil } label: {
            CategoryCover(name: name, symbol: symbol, count: count, item: cover)
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityElement(children: .ignore).accessibilityLabel("\(name), \(count) note")
            .accessibilityAddTraits(.isButton).accessibilityIdentifier("category-\(name)")
    }
    private var presentedLibrary: some View {
        library
            .sheet(isPresented: $adding) { NoteComposer { receipt in captured(receipt) } }
            .sheet(isPresented: $addingPhoto) { NoteComposer(autoPickPhoto: true) { receipt in captured(receipt) } }
            .sheet(isPresented: $managingTags) { CollectionsView() }
            .sheet(isPresented: $backup) { BackupView() }
            .sheet(isPresented: $guide) { CaptureGuideView() }
            .sheet(isPresented: $editingTags) { bulkTagEditor }
            .sheet(item: $tagNote) { NoteTagEditor(item: $0) }
            .safeAreaInset(edge: .bottom) { if selecting { selectionBar } }
            .onChange(of: visible.map(\.id)) { _, ids in
                selection.formIntersection(ids)
                if opened?.modelContext == nil { opened = nil }
                if contentRoute?.item.modelContext == nil { contentRoute = nil }
                if tagNote?.modelContext == nil { tagNote = nil }
            }
            .onChange(of: tags.map(\.id)) { _, ids in
                if case .collection(let id) = filter, !ids.contains(id) { filter = .all }
            }

            .onChange(of: sort) { _, value in UserDefaults.standard.set(value.rawValue, forKey: "library.sort") }
            .onAppear {
                sort = UserDefaults.standard.string(forKey: "library.sort").flatMap(LibrarySort.init(rawValue:)) ?? .newest
            }
            .alert("Eliminare definitivamente la nota e i suoi allegati?", isPresented: $deletePrompt) {
                Button("Elimina definitivamente", role: .destructive) {
                    if let deleting {
                        let id = deleting.id
                        do {
                            try LinkStore.deleteNote(deleting, in: context)
                            notice = "Nota eliminata"; selection.remove(id)
                            if savedID == id { savedID = nil }
                            revealed = nil
                        }
                        catch { self.error = error.localizedDescription }
                    }
                    deleting = nil
                }
                Button("Annulla", role: .cancel) { deleting = nil }
            }
            .alert("Operazione non riuscita", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Chiudi", role: .cancel) { }
            } message: { Text(error ?? "") }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !showingTags {
                Button { allNotes = false; archived = false; filter = .all; kind = nil; search = ""; selecting = false; selection = [] } label: {
                    Label("Tag", systemImage: "chevron.left").frame(minHeight: 44)
                }.accessibilityIdentifier("library-back-tags")
            }
            Text("\(visible.count) contenuti").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("library-count")
            if showingTags {
                Button("Gestisci tag", systemImage: "tag") { managingTags = true }
                    .frame(minHeight: 44).accessibilityIdentifier("library-manage-tags")
            }
            if let notice { Text(notice).font(.subheadline).foregroundStyle(.secondary) }
            if archiveUndo != nil { Button("Annulla spostamento", action: undoArchive).accessibilityIdentifier("archive-undo") }
            if let id = savedID, items.contains(where: { $0.id == id }) { Button("Apri contenuto salvato") { opened = items.first { $0.id == id } }.accessibilityIdentifier("library-open-saved") }
        }
    }
    private func card(_ item: CapturedLink) -> some View {
        ArchiveTile(item: item, compact: true, selected: selection.contains(item.id), selecting: selecting, revealed: $revealed,
                    openNote: { if !selecting { opened = item } }, openContent: { if !selecting { contentRoute = $0 } }, editTags: { tagNote = item }, select: {
                        if selecting { if selection.contains(item.id) { selection.remove(item.id) } else { selection.insert(item.id) } }
                        else { selecting = true; selection = [item.id]; revealed = nil }
                    }, archive: { archive(item) }, delete: { deleting = item; deletePrompt = true })
    }
    private func archive(_ item: CapturedLink) {
        do {
            let previous = item.isArchived
            try LinkStore.setArchived(!previous, for: item, in: context)
            archiveUndo = ArchiveUndo(ids: [item.id], wasArchived: previous)
            notice = previous ? "Nota ripristinata" : "Nota archiviata"
        } catch { self.error = error.localizedDescription }
    }
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button(archived ? "Torna alla libreria" : "Archivio", systemImage: "archivebox") { archived.toggle(); filter = .all; allNotes = true; search = ""; kind = nil }.accessibilityIdentifier("settings-archive")
                Button("Gestisci tag", systemImage: "tag") { managingTags = true }
                Picker("Formato", selection: $kind) {
                    Text("Tutti").tag(Optional<ContentKind>.none)
                    ForEach(ContentKind.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                }
                Picker("Ordina", selection: $sort) { ForEach(LibrarySort.allCases) { Text($0.label).tag($0) } }
                Button("Backup locale", systemImage: "externaldrive") { backup = true }
                Button("Come salvare dai social") { guide = true }
            } label: { Label("Impostazioni", systemImage: "gearshape") }.accessibilityIdentifier("library-settings")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(selecting ? "Fine" : "Seleziona") { if showingTags { allNotes = true }; selecting.toggle(); selection.removeAll(); revealed = nil }.accessibilityIdentifier("library-select")
        }
        ToolbarItem(placement: .primaryAction) {
            Button { adding = true } label: { Label("Aggiungi nota", systemImage: "plus") }.accessibilityIdentifier("capture-add").disabled(selecting)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { addingPhoto = true } label: { Label("Aggiungi foto", systemImage: "photo.badge.plus") }.accessibilityIdentifier("capture-photo").disabled(selecting)
        }
    }
    private func captured(_ receipt: CaptureReceipt) {
        savedID = receipt.id; filter = .all; kind = nil; search = ""; archived = false
        notice = receipt.inserted ? "Nota salvata" : "Link già presente: nota esistente conservata."
    }
    private var selectionBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(selection.count) selezionati"); Spacer()
                Button("Seleziona visibili") { selection = Set(visible.map(\.id)) }.frame(minHeight: 44).accessibilityIdentifier("bulk-select-all")
                Button("Deseleziona") { selection.removeAll() }.frame(minHeight: 44).disabled(selection.isEmpty)
            }.font(.subheadline)
            HStack {
                Button("Tag", systemImage: "tag") { bulkTags = []; bulkMode = .add; editingTags = true }.disabled(selection.isEmpty)
                Spacer()
                Button(archived ? "Ripristina" : "Archivia", systemImage: "archivebox") {
                    do {
                        let ids = selection
                        _ = try LinkStore.apply(.archived(!archived), to: ids, in: context)
                        archiveUndo = ArchiveUndo(ids: ids, wasArchived: archived)
                        notice = "Aggiornate \(ids.count) note"; selection.removeAll()
                    }
                    catch { self.error = error.localizedDescription }
                }.accessibilityIdentifier("bulk-archive-action").disabled(selection.isEmpty)
            }
        }.padding().background(.regularMaterial)
    }
    private var bulkTagEditor: some View {
        NavigationStack {
            Form {
                Picker("Operazione", selection: $bulkMode) { ForEach(LinkStore.TagChange.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                Text(bulkMode == .replace ? "Sostituisce tutti i tag delle note selezionate." : "Gli altri tag delle note restano invariati.").font(.subheadline).foregroundStyle(.secondary)
                TagSelection(selected: $bulkTags)
            }
                .navigationTitle("Tag della selezione")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { editingTags = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Applica") {
                            do {
                                let chosen = items.filter { selection.contains($0.id) }
                                guard chosen.count == selection.count else { throw LibraryError.selectionMissing }
                                try LinkStore.setTags(bulkTags, for: chosen, mode: bulkMode, in: context)
                                editingTags = false; selection.removeAll()
                            } catch { editingTags = false; self.error = error.localizedDescription }
                        }
                    }
                }
        }
    }
    private func undoArchive() {
        guard let action = archiveUndo else { return }
        do {
            _ = try LinkStore.apply(.archived(action.wasArchived), to: action.ids, in: context)
            archiveUndo = nil; notice = "Operazione annullata"
        } catch { self.error = error.localizedDescription }
    }
}

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
    @State private var adding = false
    @State private var addingPhoto = false
    @State private var managingTags = false
    @State private var backup = false
    @State private var guide = false
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
    private var grouped: Bool { !selecting && !allNotes && filter == .all && kind == nil && search.isEmpty && !archived }

    var body: some View {
        NavigationStack { presentedLibrary }
    }
    private var library: some View {
        List(selection: $selection) {
            header
            if visible.isEmpty {
                ContentUnavailableView("Nessuna nota", systemImage: "note.text", description: Text("Aggiungi una nota o cambia i filtri."))
            } else if grouped {
                let tagGroups = memberships(visible)
                Section {
                    ForEach(Array(visible.prefix(4))) { item in card(item).id("recent:\(item.id)") }
                } header: { sectionHeading("Recenti") { allNotes = true } }
                let undefined = visible.filter { $0.tagIDs.isEmpty }
                if !undefined.isEmpty {
                    Section {
                        ForEach(Array(undefined.prefix(3))) { item in card(item).id("unfiled:\(item.id)") }
                    } header: { sectionHeading("Da specificare") { filter = .unfiled } }
                }
                ForEach(tags.filter { tagGroups[$0.id] != nil }) { tag in
                    Section {
                        ForEach(Array((tagGroups[tag.id] ?? []).prefix(3))) { item in card(item).id("tag:\(tag.id):\(item.id)") }
                    } header: { sectionHeading(tag.name) { filter = .collection(tag.id) } }
                }
            } else {
                ForEach(visible) { item in
                    if selecting {
                        Text(item.displayTitle).tag(item.id).padding(.vertical, 8)
                    } else { card(item).id("all:\(item.id)") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(selecting ? .active : .inactive))
        .navigationTitle("Bloom")
        .searchable(text: $search, prompt: "Cerca note, testi e tag")
        .navigationDestination(item: $opened) { ContentViewer(item: $0) }
        .toolbar { toolbar }
    }
    private func memberships(_ notes: [CapturedLink]) -> [UUID: [CapturedLink]] {
        var groups: [UUID: [CapturedLink]] = [:]
        for note in notes {
            for id in note.tagIDs { groups[id, default: []].append(note) }
        }
        return groups
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
            .onChange(of: visible.map(\.id)) { _, ids in selection.formIntersection(ids) }
            .onChange(of: tags.map(\.id)) { _, ids in
                if case .collection(let id) = filter, !ids.contains(id) { filter = .all }
            }
            .onChange(of: filter) { _, value in UserDefaults.standard.set(BloomPreferences.rawFilter(value), forKey: "notes.library.filter") }
            .onChange(of: sort) { _, value in UserDefaults.standard.set(value.rawValue, forKey: "library.sort") }
            .onAppear {
                filter = BloomPreferences.collectionFilter(UserDefaults.standard.string(forKey: "notes.library.filter"))
                if case .collection(let id) = filter, !tags.contains(where: { $0.id == id }) { filter = .all }
                sort = UserDefaults.standard.string(forKey: "library.sort").flatMap(LibrarySort.init(rawValue:)) ?? .newest
            }
            .alert("Operazione non riuscita", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Chiudi", role: .cancel) { }
            } message: { Text(error ?? "") }
    }

    private var header: some View {
        Section {
            Picker("Stato", selection: $archived) { Text("Libreria").tag(false); Text("Archivio").tag(true) }.pickerStyle(.segmented)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterButton("Tutti", value: .all)
                    filterButton("Da specificare", value: .unfiled)
                    ForEach(tags) { tag in filterButton(tag.name, value: .collection(tag.id)) }
                }.padding(.vertical, 4)
            }
            HStack {
                Text("\(visible.count) contenuti").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("library-count")
                Spacer()
                Button(allNotes ? "Per tag" : "Tutte le note") { allNotes.toggle() }.font(.subheadline)
            }
            if let notice { Text(notice).font(.subheadline).foregroundStyle(.secondary) }
            if archiveUndo != nil { Button("Annulla spostamento", action: undoArchive).accessibilityIdentifier("archive-undo") }
            if let id = savedID { Button("Apri contenuto salvato") { opened = items.first { $0.id == id } }.accessibilityIdentifier("library-open-saved") }
        }
    }
    private func filterButton(_ name: String, value: CollectionFilter) -> some View {
        Button { filter = value } label: {
            Text(name).font(.subheadline).padding(.horizontal, 12).frame(minHeight: 44)
                .background(filter == value ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08), in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(filter == value ? [.isSelected] : [])
    }
    private func sectionHeading(_ name: String, action: @escaping () -> Void) -> some View {
        HStack { Text(name).font(.headline); Spacer(); Button("Vedi tutte", action: action).font(.subheadline) }.textCase(nil)
    }
    private func card(_ item: CapturedLink) -> some View {
        NoteCard(item: item, tags: tags, editTags: { if !selecting { tagNote = item } }) { if !selecting { opened = item } }
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
            .highPriorityGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                selecting = true; selection = [item.id]
            })
            .swipeActions(allowsFullSwipe: false) {
                Button(archived ? "Ripristina" : "Archivia", systemImage: "archivebox") {
                    do {
                        let previous = item.isArchived
                        try LinkStore.setArchived(!previous, for: item, in: context)
                        archiveUndo = ArchiveUndo(ids: [item.id], wasArchived: previous)
                        notice = previous ? "Nota ripristinata" : "Nota archiviata"
                    }
                    catch { self.error = error.localizedDescription }
                }.tint(.orange)
            }
    }
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button("Gestisci tag", systemImage: "tag") { managingTags = true }
                Picker("Formato", selection: $kind) {
                    Text("Tutti").tag(Optional<ContentKind>.none)
                    ForEach(ContentKind.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                }
                Picker("Ordina", selection: $sort) { ForEach(LibrarySort.allCases) { Text($0.label).tag($0) } }
                Button("Backup locale", systemImage: "externaldrive") { backup = true }
                Button("Come salvare dai social") { guide = true }
            } label: { Label("Strumenti", systemImage: "slider.horizontal.3") }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(selecting ? "Fine" : "Seleziona") { selecting.toggle(); selection.removeAll() }.accessibilityIdentifier("library-select")
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
                Button("Seleziona visibili") { selection = Set(visible.map(\.id)) }.accessibilityIdentifier("bulk-select-all")
                Button("Deseleziona") { selection.removeAll() }.disabled(selection.isEmpty)
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

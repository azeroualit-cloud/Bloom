import SwiftUI
import SwiftData

@MainActor
struct RediscoveryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var items: [CapturedLink]
    @Query private var collections: [LinkCollection]
    @State private var collectionFilter = CollectionFilter.all
    @State private var kindFilter: ContentKind?
    @State private var proposedIDs = Set<UUID>()
    @State private var round = 0
    @State private var day = Self.currentDay
    @State private var error: String?
    @State private var opened: CapturedLink?
    @State private var tagNote: CapturedLink?
    @State private var deleting: CapturedLink?
    @State private var deletePrompt = false
    @State private var revealed: UUID?
    @State private var loadedPreferences = false
    let openLibrary: () -> Void

    private static var currentDay: Int { Int(Date().timeIntervalSince1970 / 86_400) }

    private var eligible: [CapturedLink] {
        items.filter { LibraryFilter.matches($0, search: "", archived: false, collection: collectionFilter, kind: kindFilter) }
    }

    private var feed: [CapturedLink] {
        let candidates = eligible.map {
            RediscoveryCandidate(id: $0.id, kind: $0.kind, collectionID: $0.tagIDs.sorted { $0.uuidString < $1.uuidString }.first,
                host: $0.kind == .link ? URL(string: $0.urlString)?.host?.lowercased() : nil,
                isArchived: $0.isArchived)
        }
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return RediscoveryPlanner.select(candidates, day: day, round: round, excluding: proposedIDs).compactMap { byID[$0] }
    }

    var body: some View {
        NavigationStack {
            let contents = feed
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        Color.clear.frame(height: 0).id("feed-start")
                        if collectionFilter != .all || kindFilter != nil {
                            Text("Filtri attivi: \(collectionName) · \(kindFilter?.label ?? "Tutti i formati")")
                                .font(.subheadline)
                        }
                        if contents.isEmpty {
                            ContentUnavailableView {
                                Label(eligible.isEmpty ? "Niente da riscoprire" : "Tutti i contenuti proposti", systemImage: "sparkles")
                            } description: {
                                Text(eligible.isEmpty ? "Cambia filtri, aggiungi contenuti o ripristinali dal Cestino."
                                    : "Hai esaurito i contenuti disponibili per questi filtri. Puoi ricominciare il giro.")
                            } actions: {
                                if !eligible.isEmpty { Button("Ricomincia") { resetRounds() }.accessibilityIdentifier("rediscovery-restart") }
                                else { Button("Vai alla libreria", action: openLibrary) }
                            }
                        }
                        LazyVStack(spacing: 16) {
                            ForEach(contents) { item in
                                ArchiveTile(item: item, revealed: $revealed, openNote: { opened = item }, editTags: { tagNote = item }, select: { opened = item }, archive: {
                                    do { try LinkStore.setArchived(true, for: item, in: context) }
                                    catch { self.error = error.localizedDescription }
                                }, delete: { deleting = item; deletePrompt = true })
                            }
                        }
                        if !contents.isEmpty {
                            VStack(spacing: 8) {
                                Text("Fine del giro").font(.headline)
                                Text("Puoi ritrovare tutti i contenuti nella Libreria.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Button("Nuovo giro", action: newRound).buttonStyle(.bordered)
                            }.frame(maxWidth: .infinity).padding(.vertical)
                        }
                    }
                    .padding(.vertical, 8).frame(maxWidth: 680).frame(maxWidth: .infinity)
                }
                .onChange(of: round) { _, _ in proxy.scrollTo("feed-start", anchor: .top) }
                .onChange(of: collectionFilter) { _, _ in proxy.scrollTo("feed-start", anchor: .top) }
                .onChange(of: kindFilter) { _, _ in proxy.scrollTo("feed-start", anchor: .top) }
            }
            .bloomCanvas().navigationTitle("Riscopri")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $opened) { ContentViewer(item: $0) }
            .onChange(of: contents.map(\.id)) { _, _ in
                if opened?.modelContext == nil || opened?.isArchived == true { opened = nil }
                if tagNote?.modelContext == nil { tagNote = nil }
            }
            .sheet(item: $tagNote) { NoteTagEditor(item: $0) }
            .alert("Spostare la nota nel cestino?", isPresented: $deletePrompt) {
                Button("Sposta nel cestino", role: .destructive) {
                    if let deleting { do { try LinkStore.setArchived(true, for: deleting, in: context) } catch { self.error = error.localizedDescription } }
                    deleting = nil
                }
                Button("Annulla", role: .cancel) { deleting = nil }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu { ContentFilterOptions(collection: $collectionFilter, kind: $kindFilter) }
                        label: { Label("Filtri", systemImage: "line.3.horizontal.decrease.circle") }
                }
                ToolbarItem(placement: .primaryAction) { Button("Nuovo giro", systemImage: "shuffle", action: newRound).accessibilityIdentifier("rediscovery-next").disabled(contents.isEmpty) }
            }
            .refreshable { if feed.isEmpty { resetRounds() } else { newRound() } }
            .onAppear(perform: loadPreferences)
            .onChange(of: collectionFilter) { _, _ in
                savePreferences()
                restoreHistory()
            }
            .onChange(of: kindFilter) { _, _ in
                savePreferences()
                restoreHistory()
            }
            .onChange(of: day) { _, _ in restoreHistory() }
            .onChange(of: collections.map(\.id)) { _, ids in
                if case .collection(let id) = collectionFilter, !ids.contains(id) { collectionFilter = .all }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { day = Self.currentDay }
            }
            .alert("Operazione non riuscita", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { }
            } message: { Text(error ?? "") }
        }
    }

    private var collectionName: String {
        switch collectionFilter {
        case .all: return "Tutti i tag"
        case .unfiled: return "Da specificare"
        case .collection(let id): return collections.first { $0.id == id }?.name ?? "Tag"
        }
    }
    private var historyKey: String {
        "rediscovery.history.\(day).\(BloomPreferences.rawFilter(collectionFilter) ?? "all").\(kindFilter?.rawValue ?? "all")"
    }
    private func loadPreferences() {
        guard !loadedPreferences else { return }
        loadedPreferences = true
        collectionFilter = BloomPreferences.collectionFilter(UserDefaults.standard.string(forKey: "rediscovery.collectionFilter"))
        kindFilter = UserDefaults.standard.string(forKey: "rediscovery.kindFilter").flatMap(ContentKind.init(rawValue:))
        restoreHistory()
    }
    private func savePreferences() {
        guard loadedPreferences else { return }
        UserDefaults.standard.set(BloomPreferences.rawFilter(collectionFilter), forKey: "rediscovery.collectionFilter")
        UserDefaults.standard.set(kindFilter?.rawValue, forKey: "rediscovery.kindFilter")
    }
    private func restoreHistory() {
        guard loadedPreferences else { return }
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let history = try? JSONDecoder().decode(RediscoveryHistory.self, from: data), history.day == day else {
            proposedIDs.removeAll(); round = 0; return
        }
        proposedIDs = Set(history.proposedIDs)
        round = proposedIDs.isEmpty ? 0 : 1
    }
    private func persistHistory() {
        let history = RediscoveryHistory(day: day, proposedIDs: Array(proposedIDs))
        UserDefaults.standard.set(try? JSONEncoder().encode(history), forKey: historyKey)
    }
    private func resetRounds() {
        proposedIDs.removeAll(); round = 0
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
    private func newRound() {
        proposedIDs.formUnion(feed.map(\.id)); round += 1; day = Self.currentDay
        persistHistory()
    }
}

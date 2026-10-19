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
    @State private var loadedPreferences = false
    let openLibrary: () -> Void

    private static var currentDay: Int { Int(Date().timeIntervalSince1970 / 86_400) }

    private var eligible: [CapturedLink] {
        items.filter { LibraryFilter.matches($0, search: "", archived: false, collection: collectionFilter, kind: kindFilter) }
    }

    private var feed: [CapturedLink] {
        let candidates = eligible.map {
            RediscoveryCandidate(id: $0.id, kind: $0.kind, collectionID: $0.collection?.id,
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
                        Text("Contenuti dalla tua libreria. Fino a 30 per giro, con varietà di formati e raccolte.")
                            .font(.subheadline).foregroundStyle(.secondary).id("feed-start")
                        if collectionFilter != .all || kindFilter != nil {
                            Text("Filtri attivi: \(collectionName) · \(kindFilter?.label ?? "Tutti i formati")")
                                .font(.subheadline)
                        }
                        if contents.isEmpty {
                            ContentUnavailableView {
                                Label(eligible.isEmpty ? "Niente da riscoprire" : "Tutti i contenuti proposti", systemImage: "sparkles")
                            } description: {
                                Text(eligible.isEmpty ? "Cambia filtri, aggiungi contenuti o ripristinali dall’Archivio."
                                    : "Hai esaurito i contenuti disponibili per questi filtri. Puoi ricominciare il giro.")
                            } actions: {
                                if !eligible.isEmpty { Button("Ricomincia") { resetRounds() }.accessibilityIdentifier("rediscovery-restart") }
                                else { Button("Vai alla libreria", action: openLibrary) }
                            }
                        }
                        ForEach(contents) { item in
                            RediscoveryCard(item: item, collections: collections, archive: {
                                do { try LinkStore.setArchived(true, for: item, in: context) }
                                catch { self.error = error.localizedDescription }
                            }, move: { collection in
                                do { try LinkStore.update(item, title: item.title ?? "", notes: item.notes ?? "", collection: collection, in: context) }
                                catch { self.error = error.localizedDescription }
                            })
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
                    .padding().frame(maxWidth: 680).frame(maxWidth: .infinity)
                }
                .onChange(of: round) { _, _ in proxy.scrollTo("feed-start", anchor: .top) }
                .onChange(of: collectionFilter) { _, _ in proxy.scrollTo("feed-start", anchor: .top) }
                .onChange(of: kindFilter) { _, _ in proxy.scrollTo("feed-start", anchor: .top) }
            }
            .navigationTitle("Riscopri")
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
            .alert("Archiviazione non riuscita", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { }
            } message: { Text(error ?? "") }
        }
    }

    private var collectionName: String {
        switch collectionFilter {
        case .all: return "Tutte le raccolte"
        case .unfiled: return "Senza raccolta"
        case .collection(let id): return collections.first { $0.id == id }?.name ?? "Raccolta"
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

private struct RediscoveryCard: View {
    let item: CapturedLink
    let collections: [LinkCollection]
    let archive: () -> Void
    let move: (LinkCollection?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(item.kind.label, systemImage: item.kind.symbol).font(.subheadline).foregroundStyle(.secondary)
            Text(item.displayTitle).font(.title3.bold()).lineLimit(3)
            if let collection = item.collection {
                Label(collection.name, systemImage: "folder").font(.caption)
            }
            if item.kind == .image {
                AttachmentThumbnail(item: item, maximumPixelSize: 768).frame(maxHeight: 320)
            } else if item.kind == .text {
                Text(String((item.textContent ?? "").prefix(600))).lineLimit(8)
            } else if item.kind == .link {
                Text(item.urlString).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            } else {
                Text(item.fileName ?? "File").font(.subheadline).lineLimit(2)
                if let count = item.attachmentByteCount {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let notes = item.notes { Text(String(notes.prefix(300))).font(.subheadline).lineLimit(3) }
            Text(item.capturedAt, style: .date).font(.caption).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack { openButton; Spacer(); organizeMenu; archiveButton }
                VStack(alignment: .leading) { openButton; organizeMenu; archiveButton }
            }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var openButton: some View {
        NavigationLink { ContentViewer(item: item) } label: {
            Label("Apri contenuto", systemImage: "arrow.up.right.square")
        }.buttonStyle(.borderedProminent)
    }
    private var archiveButton: some View {
        Button("Archivia", systemImage: "archivebox", action: archive).buttonStyle(.bordered)
            .accessibilityHint("Sposta in Archivio. Puoi ripristinare dalla Libreria.")
    }
    private var organizeMenu: some View {
        Menu {
            Button("Senza raccolta") { move(nil) }
            ForEach(collections) { collection in
                Button(collection.name) { move(collection) }
            }
        } label: {
            Label("Raccolta", systemImage: "folder")
        }.buttonStyle(.bordered)
    }
}

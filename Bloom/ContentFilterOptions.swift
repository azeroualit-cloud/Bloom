import SwiftUI
import SwiftData

/// The same filtering vocabulary in Library and Rediscovery.
struct ContentFilterOptions: View {
    @Query(sort: \LinkCollection.name) private var collections: [LinkCollection]
    @Binding var collection: CollectionFilter
    @Binding var kind: ContentKind?

    var body: some View {
        Picker("Raccolta", selection: $collection) {
            Text("Tutte le raccolte").tag(CollectionFilter.all)
            Text("Senza raccolta").tag(CollectionFilter.unfiled)
            ForEach(collections) { Text($0.name).tag(CollectionFilter.collection($0.id)) }
        }
        Picker("Formato", selection: $kind) {
            Text("Tutti i formati").tag(Optional<ContentKind>.none)
            ForEach(ContentKind.allCases, id: \.self) { kind in
                Label(kind.label, systemImage: kind.symbol).tag(Optional(kind))
            }
        }
        Button("Azzera filtri") { collection = .all; kind = nil }
    }
}

struct CaptureCollectionSection: View {
    @Query(sort: \LinkCollection.name) private var collections: [LinkCollection]
    @Binding var selection: UUID?
    @State private var creating = false

    var body: some View {
        Section("Raccolta") {
            Picker("Salva in", selection: $selection) {
                Text("Senza raccolta").tag(Optional<UUID>.none)
                ForEach(collections) { Text($0.name).tag(Optional($0.id)) }
            }
            Button("Crea raccolta", systemImage: "folder.badge.plus") { creating = true }
                .sheet(isPresented: $creating) { CollectionNameEditor(collection: nil) { selection = $0.id } }
        }
    }
}

struct ImportOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    let kind: ContentKind
    let onContinue: (UUID?) -> Void
    @State private var collectionID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                CaptureCollectionSection(selection: $collectionID)
                Text("Il contenuto sarà copiato in Bloom. Limite 25 MB per elemento.").foregroundStyle(.secondary)
            }
            .navigationTitle(kind == .image ? "Importa foto" : "Importa file")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if collectionID == nil { collectionID = BloomPreferences.lastCaptureCollectionID } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Scegli") { BloomPreferences.lastCaptureCollectionID = collectionID; onContinue(collectionID); dismiss() }
                }
            }
        }
    }
}

import SwiftUI
import SwiftData

/// The same filtering vocabulary in Library and Rediscovery.
struct ContentFilterOptions: View {
    @Query(sort: \LinkCollection.name) private var collections: [LinkCollection]
    @Binding var collection: CollectionFilter
    @Binding var kind: ContentKind?

    var body: some View {
        Picker("Tag", selection: $collection) {
            Text("Tutti i tag").tag(CollectionFilter.all)
            Text("Da organizzare").tag(CollectionFilter.unfiled)
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

import SwiftUI
import SwiftData

struct CollectionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \LinkCollection.name) private var collections: [LinkCollection]
    @State private var creating = false
    @State private var editing: LinkCollection?
    @State private var deleting: LinkCollection?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if collections.isEmpty {
                    ContentUnavailableView("Nessuna raccolta", systemImage: "folder",
                        description: Text("Crea una raccolta per organizzare i tuoi contenuti."))
                }
                ForEach(collections) { collection in
                    Button { editing = collection } label: {
                        LabeledContent(collection.name, value: "\(collection.links.count)")
                    }
                    .swipeActions(allowsFullSwipe: false) {
                        Button("Elimina", role: .destructive) { deleting = collection }
                    }
                }
            }
            .navigationTitle("Raccolte")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fine") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Nuova raccolta", systemImage: "plus") { creating = true }
                }
            }
            .sheet(isPresented: $creating) { CollectionNameEditor(collection: nil) }
            .sheet(item: $editing) { CollectionNameEditor(collection: $0) }
            .confirmationDialog("Eliminare la raccolta?", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("Elimina raccolta", role: .destructive) {
                    guard let collection = deleting else { return }
                    do { try LinkStore.deleteCollection(collection, in: context) }
                    catch { self.error = error.localizedDescription }
                    deleting = nil
                }
                Button("Annulla", role: .cancel) { deleting = nil }
            } message: { Text("I contenuti restano nella libreria, senza raccolta.") }
            .alert("Operazione non riuscita", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { }
            } message: { Text(error ?? "") }
        }
    }
}

struct CollectionNameEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let collection: LinkCollection?
    let onSaved: (LinkCollection) -> Void
    @State private var name: String
    @State private var error: String?

    init(collection: LinkCollection?, onSaved: @escaping (LinkCollection) -> Void = { _ in }) {
        self.collection = collection
        self.onSaved = onSaved
        _name = State(initialValue: collection?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome raccolta", text: $name)
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(collection == nil ? "Nuova raccolta" : "Rinomina raccolta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        do {
                            let saved = try LinkStore.saveCollection(collection, name: name, in: context)
                            onSaved(saved)
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("collection-save").disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: name) { _, _ in error = nil }
        }
    }
}

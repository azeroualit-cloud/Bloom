import SwiftUI
import SwiftData

struct CollectionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \LinkCollection.name) private var collections: [LinkCollection]
    @Query private var items: [CapturedLink]
    @State private var creating = false
    @State private var editing: LinkCollection?
    @State private var deleting: LinkCollection?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if collections.isEmpty {
                    ContentUnavailableView("Nessun tag", systemImage: "tag",
                        description: Text("Crea un tag per organizzare le tue note."))
                }
                ForEach(collections) { collection in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(collection.name).font(.headline)
                            Text("\(items.filter { $0.tagIDs.contains(collection.id) }.count) note").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { editing = collection } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                            .accessibilityLabel("Rinomina \(collection.name)").accessibilityIdentifier("tag-rename-\(collection.name)")
                        Button(role: .destructive) { deleting = collection } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                            .accessibilityLabel("Elimina \(collection.name)").accessibilityIdentifier("tag-delete-\(collection.name)")
                    }
                    .buttonStyle(.borderless)
                    .swipeActions(allowsFullSwipe: false) {
                        Button("Elimina", role: .destructive) { deleting = collection }
                    }
                }
            }
            .bloomCanvas().navigationTitle("Tag")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fine") { dismiss() }.accessibilityIdentifier("tags-done") }
                ToolbarItem(placement: .primaryAction) {
                    Button("Nuovo tag", systemImage: "plus") { creating = true }
                }
            }
            .sheet(isPresented: $creating) { CollectionNameEditor(collection: nil) }
            .sheet(item: $editing) { CollectionNameEditor(collection: $0) }
            .confirmationDialog("Eliminare il tag?", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("Elimina tag", role: .destructive) {
                    guard let collection = deleting else { return }
                    do { try LinkStore.deleteCollection(collection, in: context) }
                    catch { self.error = error.localizedDescription }
                    deleting = nil
                }
                Button("Annulla", role: .cancel) { deleting = nil }
            } message: { Text("Le note restano nella libreria e conservano gli altri tag.") }
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
                TextField("Tag · una parola", text: $name).autocorrectionDisabled().accessibilityIdentifier("collection-name")
                if let error { Text(error).foregroundStyle(.red) }
            }
            .bloomCanvas().navigationTitle(collection == nil ? "Nuovo tag" : "Rinomina tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        do {
                            let clean = try NoteTags.validate(name)
                            let saved = try LinkStore.saveCollection(collection, name: clean, in: context)
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

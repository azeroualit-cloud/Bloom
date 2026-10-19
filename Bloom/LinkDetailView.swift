import SwiftUI
import SwiftData

struct LinkDetailView: View {
    @Environment(\.modelContext) private var context
    let link: CapturedLink
    @State private var editing = false
    @State private var titles = LinkTitleController()
    @State private var error: String?

    var body: some View {
        Form {
            if link.kind == .link {
                Section("Indirizzo salvato") {
                    Text(link.urlString).textSelection(.enabled)
                    if link.title == nil {
                        Button("Recupera titolo dal sito") { titles.start([link], in: context) }.disabled(titles.isLoading)
                    }
                    if titles.isLoading { ProgressView("Recupero titolo…"); Button("Annulla") { titles.cancel() } }
                    if let message = titles.message { Text(message).font(.subheadline).foregroundStyle(.secondary) }
                    if let url = URL(string: link.urlString) { Link("Apri nel browser", destination: url) }
                }
            } else if link.kind == .text {
                Section("Testo") { Text(link.textContent ?? "Testo non disponibile").textSelection(.enabled).accessibilityIdentifier("detail-content-text") }
            } else { AttachmentView(item: link) }
            Section { Text(link.capturedAt, format: .dateTime).foregroundStyle(.secondary) }
            Section("Organizzazione") {
                LabeledContent("Raccolta", value: link.collection?.name ?? "Senza raccolta")
                LabeledContent("Stato", value: link.isArchived ? "Archiviato" : "Attivo")
                if let notes = link.notes { Text(notes).textSelection(.enabled) }
            }
            Section {
                Button(link.isArchived ? "Ripristina nella libreria" : "Archivia", systemImage: "archivebox") {
                    do { try LinkStore.setArchived(!link.isArchived, for: link, in: context) }
                    catch { self.error = error.localizedDescription }
                }
            }
        }
        .onDisappear { titles.cancel() }
        .navigationTitle(link.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Modifica") { editing = true } }
        .sheet(isPresented: $editing) { LinkEditor(link: link) }
        .alert("Operazione non riuscita", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(error ?? "") }
    }
}

private struct LinkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \LinkCollection.name) private var collections: [LinkCollection]
    let link: CapturedLink
    @State private var title: String
    @State private var notes: String
    @State private var collectionID: UUID?
    @State private var creatingCollection = false
    @State private var error: String?

    init(link: CapturedLink) {
        self.link = link
        _title = State(initialValue: link.title ?? "")
        _notes = State(initialValue: link.notes ?? "")
        _collectionID = State(initialValue: link.collection?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Titolo e note") {
                    TextField("Titolo facoltativo", text: $title, axis: .vertical)
                    TextField("Note facoltative", text: $notes, axis: .vertical).lineLimit(3...10)
                }
                Section("Raccolta") {
                    Picker("Raccolta", selection: $collectionID) {
                        Text("Senza raccolta").tag(Optional<UUID>.none)
                        ForEach(collections) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Button("Crea raccolta", systemImage: "folder.badge.plus") { creatingCollection = true }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Modifica contenuto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salva", action: save) }
            }
            .sheet(isPresented: $creatingCollection) {
                CollectionNameEditor(collection: nil) { collectionID = $0.id }
            }
        }
    }

    private func save() {
        do {
            let selected = collections.first { $0.id == collectionID }
            if collectionID != nil && selected == nil { throw LibraryError.collectionMissing }
            try LinkStore.update(link, title: title, notes: notes, collection: selected, in: context)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

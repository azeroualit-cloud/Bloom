import SwiftUI
import SwiftData
import UIKit

struct LinkDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LinkCollection.name) private var tags: [LinkCollection]
    let link: CapturedLink
    @State private var editing = false
    @State private var titles = LinkTitleController()
    @State private var error: String?

    var body: some View {
        Form {
            if link.kind == .link {
                Section("Indirizzo salvato") {
                    Text(link.urlString).textSelection(.enabled)
                    Button("Copia link", systemImage: "doc.on.doc") { UIPasteboard.general.string = link.urlString }
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
                LabeledContent("Tag", value: tagNames)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Tag")
                    .accessibilityValue(tagNames)
                    .accessibilityIdentifier("detail-collection")
                LabeledContent("Stato", value: link.isArchived ? "Nel cestino" : "Attivo")
                if let notes = link.notes { Text(notes).textSelection(.enabled) }
            }
            Section {
                Button(link.isArchived ? "Ripristina nella libreria" : "Sposta nel cestino", systemImage: "trash") {
                    do { try LinkStore.setArchived(!link.isArchived, for: link, in: context) }
                    catch { self.error = error.localizedDescription }
                }
            }
        }
        .onDisappear { titles.cancel() }
        .bloomCanvas().navigationTitle(link.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Modifica") { editing = true } }
        .sheet(isPresented: $editing) { NoteComposer(item: link) { _ in } }
        .alert("Operazione non riuscita", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(error ?? "") }
    }
    private var tagNames: String {
        let names = tags.filter { link.tagIDs.contains($0.id) }.map(\.name)
        return names.isEmpty ? "Da specificare" : names.joined(separator: " · ")
    }
}

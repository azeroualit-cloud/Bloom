import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Resolves by identity on every render so edits never keep displaying an old copy.
@MainActor
struct NoteAttachmentView: View {
    @Environment(\.modelContext) private var context
    let item: CapturedLink
    let fileID: UUID
    @State private var framing = false
    @State private var editing = false
    @State private var draft = ""
    @State private var error: String?
    private var file: NoteFile? { item.noteFiles.first { $0.id == fileID } }

    var body: some View {
        Group {
            if let file {
                if UTType(file.type)?.conforms(to: .image) == true {
                    FramedImage(data: file.data, framing: ImageFraming(), zoomable: true)
                        .background(.black).ignoresSafeArea(edges: .bottom)
                        .toolbar { Button("Inquadratura") { framing = true } }
                } else if let text = DocumentText.decode(file.data, name: file.name, type: file.type) {
                    ScrollView { MarkdownDocumentView(text: text).padding(20) }
                        .toolbar { Button("Modifica") { draft = text; editing = true } }
                } else { NoteFileView(file: file, autoPreview: true) }
            } else { ContentUnavailableView("Allegato non disponibile", systemImage: "paperclip") }
        }
        .navigationTitle(file?.name ?? "Allegato").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $framing) { if let file { ImageFramingEditor(item: item, file: file) } }
        .sheet(isPresented: $editing) {
            NavigationStack {
                TextEditor(text: $draft).font(.body.monospaced()).padding(12).accessibilityLabel("Testo modificabile").accessibilityIdentifier("attachment-editor")
                    .navigationTitle("Modifica documento").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Annulla") { editing = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("Salva", action: save).accessibilityIdentifier("attachment-save") }
                    }
                    .interactiveDismissDisabled()
                    .alert("Salvataggio non riuscito", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                        Button("OK", role: .cancel) { }
                    } message: { Text(error ?? "") }
            }
        }
    }
    private func save() {
        guard let file else { return }
        do {
            let updated = NoteFile(id: file.id, name: file.name, type: file.type, data: Data(draft.utf8), framing: file.framing)
            try LinkStore.updateNoteFile(updated, for: item, in: context)
            editing = false
        } catch { self.error = error.localizedDescription }
    }
}

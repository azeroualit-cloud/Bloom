import SwiftUI
import SwiftData
import PhotosUI

struct TagSelection: View {
    @Query(sort: \LinkCollection.name) private var tags: [LinkCollection]
    @Binding var selected: Set<UUID>
    @State private var creating = false
    var body: some View {
        Section("Tag") {
            if selected.isEmpty { Text("Da specificare").foregroundStyle(.secondary) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108))], alignment: .leading, spacing: 8) {
                ForEach(tags) { tag in
                    Button {
                        if selected.contains(tag.id) { selected.remove(tag.id) } else { selected.insert(tag.id) }
                    } label: {
                        Text(tag.name).font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                            .background(selected.contains(tag.id) ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08), in: Capsule())
                    }.buttonStyle(.plain)
                        .accessibilityAddTraits(selected.contains(tag.id) ? [.isSelected] : [])
                        .accessibilityIdentifier("tag-\(tag.name)")
                }
            }
            Button("Nuovo tag", systemImage: "plus") { creating = true }
                .sheet(isPresented: $creating) { CollectionNameEditor(collection: nil) { selected.insert($0.id) } }
        }
    }
}

@MainActor
struct NoteComposer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let item: CapturedLink?
    let startsWithLink: Bool
    let onSaved: (CaptureReceipt) -> Void
    @State private var title: String
    @State private var bodyText: String
    @State private var linksText: String
    @State private var tags: Set<UUID>
    @State private var files: [NoteFile]
    @State private var showingFile = false
    @State private var photo: PhotosPickerItem?
    @State private var loading = false
    @State private var error: String?
    @State private var saved = false
    @State private var operation: Task<Void, Never>?
    @FocusState private var focused: Bool

    init(item: CapturedLink? = nil, startsWithLink: Bool = false, onSaved: @escaping (CaptureReceipt) -> Void) {
        self.item = item; self.startsWithLink = startsWithLink; self.onSaved = onSaved
        _title = State(initialValue: item?.title ?? "")
        _bodyText = State(initialValue: item?.noteBody ?? "")
        _linksText = State(initialValue: item?.allLinks.map(\.absoluteString).joined(separator: "\n") ?? "")
        _tags = State(initialValue: item?.tagIDs ?? [])
        _files = State(initialValue: item?.noteFiles ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Titolo") { TextField("Titolo facoltativo", text: $title).accessibilityIdentifier("capture-title").focused($focused) }
                if startsWithLink { linkSection }
                Section("Testo · Markdown") {
                    TextEditor(text: $bodyText).frame(minHeight: 150).focused($focused)
                        .accessibilityLabel("Testo della nota").accessibilityIdentifier("capture-body")
                }
                if !startsWithLink { linkSection }
                attachmentSection
                TagSelection(selected: $tags)
                if saved { Label("Nota salvata. Puoi aggiungerne un’altra.", systemImage: "checkmark.circle").foregroundStyle(.green).accessibilityIdentifier("note-saved") }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(item == nil ? "Nuova nota" : "Modifica nota").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(item == nil ? "Fine" : "Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salva", action: save).disabled(loading || isEmpty).accessibilityIdentifier("capture-save") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fine") { focused = false }.accessibilityIdentifier("capture-keyboard-done") }
            }
            .sheet(isPresented: $showingFile) {
                DocumentImportPicker { result in
                    showingFile = false
                    switch result {
                    case .success(let url): if let url { loadFile(url) }
                    case .failure(let failure): error = failure.localizedDescription
                    }
                }
            }
            .onChange(of: photo) { _, value in if let value { loadPhoto(value); photo = nil } }
            .onChange(of: bodyText) { _, _ in if !bodyText.isEmpty { saved = false } }
            .onChange(of: linksText) { _, _ in if !linksText.isEmpty { saved = false } }
            .onDisappear { operation?.cancel() }
            .interactiveDismissDisabled(loading)
        }
    }
    private var isEmpty: Bool { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && linksText.isEmpty && files.isEmpty && item == nil }
    private var linkSection: some View {
        Section("Link e video") {
            TextField("Incolla un link per riga", text: $linksText, axis: .vertical)
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("note-links").focused($focused)
            PasteButton(payloadType: String.self) { values in
                if let first = values.first { linksText += (linksText.isEmpty ? "" : "\n") + first }
            }
        }
    }
    private var attachmentSection: some View {
        Section("Allegati") {
            if item?.kind == .image || item?.kind == .file { Label(item?.fileName ?? "Allegato originale", systemImage: "paperclip") }
            ForEach(files) { file in
                HStack {
                    Label(file.name, systemImage: "paperclip").lineLimit(2); Spacer()
                    Button("Rimuovi", role: .destructive) { files.removeAll { $0.id == file.id } }.buttonStyle(.borderless)
                }
            }
            HStack {
                PhotosPicker(selection: $photo, matching: .images) { Label("Foto", systemImage: "photo") }
                Spacer(); Button("File", systemImage: "doc") { showingFile = true }
            }.disabled(loading)
            if loading { ProgressView("Importazione…") }
        }
    }
    private func append(_ payload: AttachmentPayload) throws {
        try Task.checkCancellation()
        guard files.count < 10, files.reduce(payload.data.count, { $0 + $1.data.count }) <= AttachmentLoader.maximumBytes else { throw NoteError.tooManyAttachments }
        files.append(NoteFile(name: payload.name, type: payload.type, data: payload.data))
    }
    private func loadFile(_ url: URL) {
        loading = true; error = nil
        operation = Task {
            defer { loading = false }
            do {
                let payload = try await Task.detached(priority: .userInitiated) {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    return try AttachmentLoader.readCoordinated(url)
                }.value
                try append(payload)
            } catch is CancellationError { } catch { self.error = error.localizedDescription }
        }
    }
    private func loadPhoto(_ photo: PhotosPickerItem) {
        loading = true; error = nil
        operation = Task {
            defer { loading = false }
            do {
                guard let imported = try await photo.loadTransferable(type: ImportedPhoto.self) else { throw ImportError.missingData }
                try append(imported.payload)
            } catch is CancellationError { } catch { self.error = error.localizedDescription }
        }
    }
    private func save() {
        do {
            let urls = try linksText.split(whereSeparator: { $0.isNewline }).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { line -> URL in
                guard let url = URL(string: line.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw CaptureError.invalidURL }
                return try LinkValidation.validate(url)
            }
            let receipt = try LinkStore.saveNote(existing: item, title: title, body: bodyText, urls: urls, files: files, tags: tags, in: context)
            onSaved(receipt)
            if item != nil { dismiss(); return }
            title = ""; bodyText = ""; linksText = ""; files = []; tags = []; saved = true; error = nil; focused = false
        } catch { self.error = error.localizedDescription }
    }
}

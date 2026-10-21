import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct TagSelection: View {
    @Query(sort: \LinkCollection.name) private var tags: [LinkCollection]
    @Binding var selected: Set<UUID>
    var categoryMode = false
    @State private var creating = false
    var body: some View {
        Section(categoryMode ? "Categorie" : "Tag") {
            if selected.isEmpty { Text("Da organizzare").foregroundStyle(.secondary) }
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
            Button(categoryMode ? "Nuova categoria" : "Nuovo tag", systemImage: "plus") { creating = true }
                .sheet(isPresented: $creating) { CollectionNameEditor(collection: nil, categoryMode: categoryMode) { selected.insert($0.id) } }
        }
    }
}

@MainActor
struct NoteComposer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var availableTags: [LinkCollection]
    let item: CapturedLink?
    let startsWithLink: Bool
    let autoPickPhoto: Bool
    let onSaved: (CaptureReceipt) -> Void
    private let initialDraft: NoteDraft
    @State private var title: String
    @State private var bodyText: String
    @State private var linksText: String
    @State private var tags: Set<UUID>
    @State private var place: NotePlace?
    @State private var choosingPlace = false
    @State private var placeEdited = false
    @State private var files: [NoteFile]
    @State private var showingFile = false
    @State private var showingPhoto = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var saved = false
    @State private var operation: Task<Void, Never>?
    @State private var draftTask: Task<Void, Never>?
    @State private var session = UUID()
    @State private var draftRevision = 0
    @State private var loaded = false
    @State private var preserveDraft = true
    @State private var confirmingClose = false
    @State private var restored = false
    private enum Field { case title, body, links }
    @FocusState private var focused: Field?

    init(item: CapturedLink? = nil, startsWithLink: Bool = false, autoPickPhoto: Bool = false, onSaved: @escaping (CaptureReceipt) -> Void) {
        self.item = item; self.startsWithLink = startsWithLink; self.autoPickPhoto = autoPickPhoto; self.onSaved = onSaved
        initialDraft = NoteDraft(title: item?.title ?? "", body: item?.noteBody ?? "", links: item?.allLinks.map(\.absoluteString).joined(separator: "\n") ?? "", tags: item?.tagIDs ?? [], files: item?.noteFiles ?? [], place: item?.place, placeEdited: false)
        _title = State(initialValue: item?.title ?? "")
        _bodyText = State(initialValue: item?.noteBody ?? "")
        _linksText = State(initialValue: item?.allLinks.map(\.absoluteString).joined(separator: "\n") ?? "")
        _tags = State(initialValue: item?.tagIDs ?? [])
        _place = State(initialValue: item?.place)
        _files = State(initialValue: item?.noteFiles ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Titolo") { TextField("Titolo facoltativo", text: $title).foregroundStyle(Color.bloomText).accessibilityIdentifier("capture-title").focused($focused, equals: .title) }
                if startsWithLink { linkSection }
                Section("Testo · Markdown") {
                    TextEditor(text: $bodyText).foregroundStyle(Color.bloomText).frame(minHeight: 130).focused($focused, equals: .body)
                        .accessibilityLabel("Testo della nota").accessibilityIdentifier("capture-body")
                }
                if !startsWithLink { linkSection }
                TagSelection(selected: $tags)
                attachmentSection
                Section("Luogo · facoltativo") {
                    Button { focused = nil; choosingPlace = true } label: {
                        Label(place?.name ?? "Aggiungi luogo", systemImage: "mappin.and.ellipse")
                    }.accessibilityIdentifier("note-place-picker")
                    if place != nil { Button("Rimuovi luogo", role: .destructive) { place = nil; placeEdited = true } }
                }
                if restored { Text("Bozza ripristinata").font(.caption).foregroundStyle(.secondary) }
                if saved { Label("Nota salvata. Puoi aggiungerne un’altra.", systemImage: "checkmark.circle").foregroundStyle(Color.accentColor).accessibilityIdentifier("note-saved") }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .disabled(!loaded)
            .bloomCanvas().navigationTitle(item == nil ? "Nuova nota" : "Modifica nota").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { if isDirty { confirmingClose = true } else { dismiss() } }.disabled(!loaded || loading).accessibilityIdentifier("capture-close").accessibilityValue(clipboardTestStatus) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }.fontWeight(.semibold)
                        .foregroundStyle(!loaded || loading || isEmpty ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(BloomBrand.gradient))
                        .disabled(!loaded || loading || isEmpty).accessibilityIdentifier("capture-save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if item == nil && focused != nil {
                        Button("Salva e aggiungi") { save(addAnother: true) }.disabled(!loaded || loading || isEmpty).accessibilityIdentifier("capture-save-another")
                    }
                    Spacer()
                    Button("Fine") { focused = nil }.accessibilityIdentifier("capture-keyboard-done")
                }
            }
            .safeAreaInset(edge: .top) {
                if item == nil && title.isEmpty && bodyText.isEmpty && files.isEmpty && linksText.isEmpty {
                    HStack {
                        PasteButton(payloadType: String.self) { pasteValues($0, saveImmediately: true) }
                            .buttonBorderShape(.capsule).labelStyle(.titleAndIcon)
                            .accessibilityLabel("Incolla e salva link")
                            .accessibilityIdentifier("capture-paste-save").disabled(!loaded || loading)
                        Text("e salva un link").font(.subheadline).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }.padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.bloomBackground)
                }
            }
            .safeAreaInset(edge: .bottom) { if item == nil && focused == nil { captureActions } }
            .sheet(isPresented: $choosingPlace) { PlacePicker(currentPlace: place) { place = $0; placeEdited = true } }
            .sheet(isPresented: $showingFile) {
                DocumentImportPicker { result in
                    showingFile = false
                    switch result {
                    case .success(let url): if let url { loadFile(url) }
                    case .failure(let failure): error = failure.localizedDescription
                    }
                }
            }
            .photosPicker(isPresented: $showingPhoto, selection: $photos, maxSelectionCount: 10, selectionBehavior: .ordered, matching: .any(of: [.images, .videos]))
            .onChange(of: photos) { _, values in if !values.isEmpty { loadPhotos(values); photos = [] } }
            .onChange(of: bodyText) { _, _ in if !bodyText.isEmpty { saved = false } }
            .onChange(of: linksText) { _, _ in if !linksText.isEmpty { saved = false } }
            .task { await restoreDraft() }
            .onChange(of: snapshot) { _, value in draftRevision += 1; scheduleDraft(value) }
            .onChange(of: scenePhase) { _, phase in if phase != .active { persistDraft() } }
            .onDisappear { operation?.cancel(); persistDraft() }
            .interactiveDismissDisabled(!loaded || loading || isDirty)
            .confirmationDialog("Modifiche non salvate", isPresented: $confirmingClose) {
                Button("Conserva bozza e chiudi") { closeKeepingDraft() }
                Button("Scarta modifiche", role: .destructive) { discard() }
                Button("Continua a scrivere", role: .cancel) { }
            } message: { Text("Puoi conservare la bozza e riprenderla alla prossima apertura.") }
        }
    }
    private var isEmpty: Bool { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && linksText.isEmpty && files.isEmpty && item == nil && place == nil }
    private var linkSection: some View {
        Section("Link e video") {
            TextField("Incolla un link per riga", text: $linksText, axis: .vertical)
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("note-links").focused($focused, equals: .links)
            PasteButton(payloadType: String.self) { pasteValues($0, saveImmediately: false) }
                .accessibilityLabel("Incolla link").accessibilityIdentifier("capture-paste-links")
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
                Button("Foto e video", systemImage: "photo.on.rectangle") { focused = nil; showingPhoto = true }
                Spacer(); Button("File", systemImage: "doc") { showingFile = true }
            }.buttonStyle(.borderless).disabled(loading)
            if loading { ProgressView("Importazione…") }
        }
    }
    private func append(_ payload: AttachmentPayload) throws {
        try Task.checkCancellation()
        let primaryCount = (item?.kind == .image || item?.kind == .file) ? 1 : 0
        let linkCount = linksText.split(whereSeparator: { $0.isNewline }).count
        guard files.count + primaryCount + linkCount < 10,
              files.reduce(payload.data.count + (item?.attachmentData?.count ?? 0) + bodyText.utf8.count, { $0 + $1.data.count }) <= AttachmentLoader.maximumBytes else { throw NoteError.tooManyAttachments }
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
    private func loadPhotos(_ photos: [PhotosPickerItem]) {
        loading = true; error = nil
        operation = Task {
            defer { loading = false }
            do {
                var importedFiles: [NoteFile] = []
                let primaryCount = (item?.kind == .image || item?.kind == .file) ? 1 : 0
                let linkCount = linksText.split(whereSeparator: { $0.isNewline }).count
                guard files.count + photos.count + primaryCount + linkCount <= 10 else { throw NoteError.tooManyAttachments }
                var bytes = files.reduce(item?.attachmentData?.count ?? 0, { $0 + $1.data.count }) + bodyText.utf8.count
                for photo in photos {
                    try Task.checkCancellation()
                    guard let imported = try await photo.loadTransferable(type: ImportedPhoto.self) else { throw ImportError.missingData }
                    bytes += imported.payload.data.count
                    guard bytes <= AttachmentLoader.maximumBytes else { throw NoteError.tooManyAttachments }
                    importedFiles.append(NoteFile(name: imported.payload.name, type: imported.payload.type, data: imported.payload.data))
                }
                try Task.checkCancellation()
                files.append(contentsOf: importedFiles)
            } catch is CancellationError { } catch { self.error = error.localizedDescription }
        }
    }
    private func save(addAnother: Bool = false) {
        do {
            let urls = try linksText.split(whereSeparator: { $0.isNewline }).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { line -> URL in
                guard let url = URL(string: line.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw CaptureError.invalidURL }
                return try LinkValidation.validate(url)
            }
            let receipt = try LinkStore.saveNote(existing: item, title: title, body: bodyText, urls: urls, files: files, tags: tags, location: placeEdited ? .set(place) : .keep, in: context)
            clearDraft()
            onSaved(receipt)
            if item != nil || !addAnother { dismiss(); return }
            title = ""; bodyText = ""; linksText = ""; files = []; tags = []; place = nil; placeEdited = false; saved = true; error = nil
            session = UUID(); preserveDraft = true; focused = .body
        } catch { self.error = error.localizedDescription }
    }

    private var captureActions: some View {
        HStack {
            Spacer()
            if item == nil { Button("Salva e aggiungi") { save(addAnother: true) }.disabled(!loaded || loading || isEmpty).accessibilityIdentifier("capture-save-another") }
        }.padding(12).background(.regularMaterial).disabled(!loaded || loading)
    }
    private var clipboardTestStatus: String {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-clipboard") {
            return UIPasteboard.general.hasStrings ? "clipboard-ready" : "clipboard-empty"
        }
        #endif
        return ""
    }
    private func pasteValues(_ values: [String], saveImmediately: Bool) {
        guard loaded && !loading, let text = values.first, !text.isEmpty else { return }
        linksText += (linksText.isEmpty ? "" : "\n") + text
        if saveImmediately { save() }
    }
    private var snapshot: NoteDraft { NoteDraft(title: title, body: bodyText, links: linksText, tags: tags, files: files, place: place, placeEdited: placeEdited) }
    private var isDirty: Bool { snapshot != initialDraft }
    private var draftsEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return !arguments.contains("--ui-test-in-memory") || arguments.contains(where: { $0.hasPrefix("--ui-test-drafts=") })
    }
    private func restoreDraft() async {
        guard !loaded else { return }
        if draftsEnabled {
            do {
                if let draft = try await NoteDraftStore.shared.load(item?.id, session: session), draft != initialDraft {
                    title = draft.title; bodyText = draft.body; linksText = draft.links; place = draft.place; placeEdited = draft.placeEdited == true
                    tags = draft.tags.intersection(availableTags.map(\.id)); files = draft.files; restored = true
                }
            } catch { self.error = "Non è stato possibile leggere la bozza: \(error.localizedDescription)" }
        }
        #if DEBUG
        // Seed only after the user has opened the composer, with the app in the foreground.
        if ProcessInfo.processInfo.arguments.contains("--ui-test-clipboard") {
            UIPasteboard.general.string = "https://example.com/quick-capture"
        }
        #endif
        loaded = true
        if autoPickPhoto { showingPhoto = true }
        else { focused = startsWithLink ? .links : .body }
    }
    private func scheduleDraft(_ value: NoteDraft) {
        guard loaded && preserveDraft && draftsEnabled else { return }
        draftTask?.cancel()
        let key = item?.id, token = session, revision = draftRevision
        draftTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(600))
                try Task.checkCancellation()
                try await NoteDraftStore.shared.save(value, key: key, session: token, revision: revision)
            } catch is CancellationError { } catch { self.error = "Bozza non salvata: \(error.localizedDescription)" }
        }
    }
    private func persistDraft() {
        guard loaded && preserveDraft && isDirty && draftsEnabled else { return }
        draftTask?.cancel()
        let value = snapshot, key = item?.id, token = session, revision = draftRevision
        Task { try? await NoteDraftStore.shared.save(value, key: key, session: token, revision: revision) }
    }
    private func clearDraft() {
        preserveDraft = false; draftTask?.cancel()
        let key = item?.id, token = session
        if draftsEnabled { Task { try? await NoteDraftStore.shared.clear(key, session: token) } }
    }
    private func closeKeepingDraft() {
        let value = snapshot, key = item?.id, token = session, revision = draftRevision
        draftTask?.cancel()
        Task {
            do {
                if draftsEnabled { try await NoteDraftStore.shared.saveAndClose(value, key: key, session: token, revision: revision) }
                preserveDraft = false; dismiss()
            } catch { self.error = "Bozza non salvata: \(error.localizedDescription)" }
        }
    }
    private func discard() { clearDraft(); dismiss() }
}

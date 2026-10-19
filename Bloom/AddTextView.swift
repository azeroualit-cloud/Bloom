import SwiftUI
import SwiftData

struct AddTextView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let onSaved: (CaptureReceipt) -> Void
    private enum Field { case title, text }
    @FocusState private var focusedField: Field?
    @State private var collectionID: UUID?
    @State private var savedMessage: String?
    @State private var title = ""
    @State private var text = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Titolo") { TextField("Titolo facoltativo", text: $title).accessibilityIdentifier("capture-title").focused($focusedField, equals: .title) }
                Section("Testo") {
                    TextEditor(text: $text).frame(minHeight: 220).accessibilityLabel("Testo da salvare").accessibilityIdentifier("capture-body").focused($focusedField, equals: .text)
                    PasteButton(payloadType: String.self) { values in
                        if let first = values.first { text = first }
                    }
                }
                CaptureCollectionSection(selection: $collectionID)
                if let savedMessage { Section { Label(savedMessage, systemImage: "checkmark.circle.fill").foregroundStyle(.green) } }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Aggiungi testo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fine") { focusedField = nil }.accessibilityIdentifier("capture-keyboard-done")
                }
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        do {
                            let result = try LinkStore.captureTextItem(text, title: title, collectionID: collectionID, into: context)
                            BloomPreferences.lastCaptureCollectionID = collectionID
                            onSaved(result)
                            savedMessage = result.inserted ? "Testo salvato. Puoi aggiungerne un altro." : "Testo già presente. Puoi aggiungerne un altro."
                            title = ""
                            text = ""
                        } catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("capture-save").disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { if collectionID == nil { collectionID = BloomPreferences.lastCaptureCollectionID } }
            .onChange(of: text) { _, _ in error = nil; savedMessage = nil }
        }
    }
}

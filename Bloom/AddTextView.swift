import SwiftUI
import SwiftData

struct AddTextView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let onSaved: (CaptureReceipt, Bool) -> Void
    private enum Field { case title, text }
    @FocusState private var focusedField: Field?
    @State private var collectionID: UUID?
    @State private var openAfterSave = true
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
                Toggle("Apri dopo il salvataggio", isOn: $openAfterSave)
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
                            onSaved(result, openAfterSave)
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("capture-save").disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: text) { _, _ in error = nil }
        }
    }
}

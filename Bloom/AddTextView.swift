import SwiftUI
import SwiftData

struct AddTextView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let onSaved: (Bool) -> Void
    @State private var title = ""
    @State private var text = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Titolo") { TextField("Titolo facoltativo", text: $title) }
                Section("Testo") {
                    TextEditor(text: $text).frame(minHeight: 220).accessibilityLabel("Testo da salvare")
                    PasteButton(payloadType: String.self) { values in
                        if let first = values.first { text = first }
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Aggiungi testo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        do {
                            let inserted = try LinkStore.captureText(text, title: title, into: context)
                            onSaved(inserted)
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: text) { _, _ in error = nil }
        }
    }
}

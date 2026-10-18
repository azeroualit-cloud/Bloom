import SwiftUI
import SwiftData

struct AddLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let onSaved: (Bool) -> Void
    @State private var value = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Indirizzo web") {
                    TextField("https://example.com", text: $value, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("URL da salvare")
                    PasteButton(payloadType: String.self) { values in
                        if let first = values.first { value = first }
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
                Section {
                    Text("Il link viene salvato solo su questo dispositivo. La pagina web non viene scaricata per la lettura offline.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Aggiungi link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva", action: save)
                        .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: value) { _, _ in error = nil }
        }
    }

    private func save() {
        do {
            guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw CaptureError.invalidURL
            }
            let inserted = try LinkStore.capture(url, into: context)
            onSaved(inserted)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct CaptureGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Una sola configurazione") {
                    Text("1. Apri Comandi Rapidi e crea un nuovo comando chiamato Salva in Bloom.")
                    Text("2. Nei dettagli del comando attiva Mostra nel foglio Condividi e accetta URL e testo.")
                    Text("3. Aggiungi Ottieni URL da input, usando Input comando rapido come ingresso.")
                    Text("4. Aggiungi l’azione di Bloom Salva link in Bloom e imposta URL al risultato del passaggio precedente.")
                }
                Section("Instagram, TikTok e Pinterest") {
                    Text("Condividi → Altro → Salva in Bloom. Collega sempre l’azione Bloom agli URL estratti, non all’intero testo condiviso.")
                }
                Section("YouTube") {
                    Text("Usa Copia link, poi Bloom → + → Incolla → Salva. È il percorso verificato per YouTube.")
                }
                Section("Se l’azione non compare") {
                    Text("Apri Bloom almeno una volta e cerca di nuovo l’azione in Comandi Rapidi. Puoi sempre copiare il link dall’app di origine e aggiungerlo con + → Incolla → Salva.")
                }
                Section {
                    Text("Non servono App Groups, servizi esterni o accesso alla rete per salvare l’indirizzo. La disponibilità del comando nel foglio Condividi va verificata sul dispositivo dopo la firma.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Salva dai social")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
        }
    }
}

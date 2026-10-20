import SwiftUI
import MapKit

@MainActor
struct PlacePicker: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (NotePlace) -> Void
    let currentPlace: NotePlace?
    let onRemove: (() -> Void)?
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var search: MKLocalSearch?
    @State private var loading = false
    @State private var attempted = false
    @State private var error: String?
    @State private var generation = UUID()
    @State private var lastSubmittedQuery: String?
    @FocusState private var searchFocused: Bool
    init(currentPlace: NotePlace? = nil, onRemove: (() -> Void)? = nil, onSelect: @escaping (NotePlace) -> Void) {
        self.currentPlace = currentPlace
        self.onRemove = onRemove
        self.onSelect = onSelect
        _query = State(initialValue: currentPlace?.name ?? "")
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Nome del luogo e città", text: $query).submitLabel(.search).onSubmit(runSearch)
                        .focused($searchFocused)
                        .accessibilityIdentifier("place-search")
                    Button("Cerca", action: runSearch).disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || loading)
                }
                if let currentPlace {
                    Section("Luogo attuale") {
                        Text(currentPlace.name)
                        if let onRemove {
                            Button("Rimuovi luogo", role: .destructive) { onRemove(); dismiss() }
                                .accessibilityIdentifier("place-remove")
                        }
                    }
                }
                if loading { ProgressView("Ricerca luoghi…") }
                if let error { Text(error).foregroundStyle(.red) }
                if attempted && !loading && results.isEmpty && error == nil { Text("Nessun luogo trovato. Prova ad aggiungere la città.").foregroundStyle(.secondary) }
                ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                    Button {
                        let coordinate = result.placemark.coordinate
                        let value = NotePlace(name: result.name ?? result.placemark.title ?? query, latitude: coordinate.latitude, longitude: coordinate.longitude)
                        guard value.isValid else { return }
                        onSelect(value); dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.name ?? "Luogo").foregroundStyle(.primary)
                            if let address = result.placemark.title { Text(address).font(.caption).foregroundStyle(.secondary) }
                        }.frame(minHeight: 44)
                    }
                }
                Section { Text("La ricerca usa Apple Maps e richiede una connessione. Non serve accedere alla tua posizione.").font(.caption).foregroundStyle(.secondary) }
            }.bloomCanvas().navigationTitle("Scegli luogo").navigationBarTitleDisplayMode(.inline)
                .onChange(of: query) { _, _ in
                    generation = UUID(); search?.cancel(); search = nil
                    results = []; loading = false; attempted = false; error = nil; lastSubmittedQuery = nil
                }
                .task(id: query) {
                    guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { return }
                    do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                    guard !Task.isCancelled, query != currentPlace?.name,
                          query.trimmingCharacters(in: .whitespacesAndNewlines) != lastSubmittedQuery else { return }
                    runSearch()
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } } }
                .onAppear { searchFocused = currentPlace == nil }
                .onDisappear { generation = UUID(); search?.cancel() }
        }
    }
    private func runSearch() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return }
        guard !(loading && lastSubmittedQuery == text) else { return }
        lastSubmittedQuery = text
        search?.cancel(); generation = UUID()
        let token = generation
        let request = MKLocalSearch.Request(); request.naturalLanguageQuery = text
        let operation = MKLocalSearch(request: request)
        search = operation; loading = true; attempted = true; error = nil
        Task {
            do {
                let response = try await operation.start()
                guard token == generation else { return }
                results = response.mapItems.filter { CLLocationCoordinate2DIsValid($0.placemark.coordinate) }
                loading = false; search = nil
            } catch {
                guard token == generation else { return }
                self.error = "Ricerca non riuscita. Controlla la connessione e riprova."
                results = []; loading = false; search = nil
            }
        }
    }
}

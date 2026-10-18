import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CapturedLink.capturedAt, order: .reverse) private var links: [CapturedLink]
    @State private var showingAdd = false
    @State private var showingGuide = false
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Condividi da Safari", systemImage: "square.and.arrow.up") { showingGuide = true }
                    if let notice { Text(notice).foregroundStyle(.secondary) }
                }
                if links.isEmpty {
                    ContentUnavailableView("La tua raccolta inizia qui", systemImage: "tray",
                        description: Text("Aggiungi un link con + oppure configura il comando per condividere da Safari."))
                }
                ForEach(links) { link in
                    NavigationLink {
                        LinkDetailView(link: link)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(URL(string: link.urlString)?.host ?? link.urlString).font(.headline)
                            Text(link.urlString).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            Text(link.capturedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Bloom")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Aggiungi link", systemImage: "plus") { showingAdd = true }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddLinkView { inserted in
                    notice = inserted ? "Link salvato" : "Link già presente nella raccolta"
                }
            }
            .sheet(isPresented: $showingGuide) { CaptureGuideView() }
        }
    }
}


private struct LinkDetailView: View {
    let link: CapturedLink

    var body: some View {
        Form {
            Section("Indirizzo salvato") {
                Text(link.urlString).textSelection(.enabled)
                Text(link.capturedAt, format: .dateTime).foregroundStyle(.secondary)
            }
            if let url = URL(string: link.urlString) {
                Link("Apri nel browser", destination: url)
            }
        }
        .navigationTitle("Contenuto")
        .navigationBarTitleDisplayMode(.inline)
    }
}

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \CapturedLink.capturedAt, order: .reverse) private var links: [CapturedLink]
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            List {
                if let importError {
                    Section {
                        Text(importError).foregroundStyle(.red)
                        Button("Riprova importazione", action: importCaptures)
                    }
                }
                if links.isEmpty {
                    ContentUnavailableView("La tua raccolta inizia qui", systemImage: "tray",
                        description: Text("Da Safari, condividi un link e scegli Salva in Bloom."))
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
            .refreshable { importCaptures() }
            .task { importCaptures() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { importCaptures() }
            }
        }
    }

    private func importCaptures() {
        do {
            let inbox = try CaptureInbox(root: CaptureInbox.sharedRoot())
            try LinkStore.importInbox(inbox, into: context)
            importError = nil
        } catch { importError = error.localizedDescription }
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

import SwiftUI
import SwiftData

/// Direct edits use the same persistence operations as the composer, without a second save step.
@MainActor
struct NoteOrganizationControls: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LinkCollection.name) private var categories: [LinkCollection]
    let item: CapturedLink
    @State private var expanded = false
    @State private var choosingPlace = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { expanded.toggle() } label: {
                row("Categorie", value: categoryNames, symbol: "tag", expanded: expanded)
            }.buttonStyle(.plain).accessibilityIdentifier("note-edit-categories")
                .accessibilityValue(expanded ? "Aperto" : "Chiuso")
            Button { choosingPlace = true } label: {
                row("Luogo", value: item.place?.name ?? "Aggiungi luogo", symbol: "mappin.and.ellipse", expanded: false)
            }.buttonStyle(.plain).accessibilityIdentifier("note-edit-place")
            if expanded {
                TagSelection(selected: selected, categoryMode: true)
                Text("Puoi scegliere più categorie. Le modifiche si salvano al tocco.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $choosingPlace) {
            PlacePicker(currentPlace: item.place, onRemove: { savePlace(nil) }) { savePlace($0) }
        }
        .alert("Modifica non salvata", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(error ?? "") }
    }
    private var categoryNames: String {
        let names = categories.filter { item.tagIDs.contains($0.id) }.map(\.name)
        return names.isEmpty ? "Da specificare" : names.joined(separator: " · ")
    }
    private var selected: Binding<Set<UUID>> {
        Binding(get: { item.tagIDs }, set: { value in
            guard item.modelContext != nil, !item.isDeleted else { return }
            do { try LinkStore.setTags(value, for: [item], in: context) }
            catch { self.error = error.localizedDescription }
        })
    }
    private func savePlace(_ place: NotePlace?) {
        do { try LinkStore.setPlace(place, for: item, in: context) }
        catch { error = error.localizedDescription }
    }
    private func row(_ title: String, value: String, symbol: String, expanded: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(BloomBrand.gradient).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline).foregroundStyle(Color.bloomText).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
    }
}

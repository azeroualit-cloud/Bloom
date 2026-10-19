import SwiftUI
import SwiftData

struct NoteTagEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let item: CapturedLink
    @State private var selected: Set<UUID>
    @State private var error: String?
    init(item: CapturedLink) { self.item = item; _selected = State(initialValue: item.tagIDs) }
    var body: some View {
        NavigationStack {
            Form {
                TagSelection(selected: $selected)
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Tag della nota").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fine") {
                            do { try LinkStore.setTags(selected, for: [item], in: context); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }.accessibilityIdentifier("quick-tags-save")
                    }
                }
        }
    }
}

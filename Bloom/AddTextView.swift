import SwiftUI

struct AddTextView: View {
    let onSaved: (CaptureReceipt) -> Void
    var body: some View { NoteComposer(onSaved: onSaved) }
}

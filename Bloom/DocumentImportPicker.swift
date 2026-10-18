import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Import a system-provided copy rather than retaining an external document URL.
struct DocumentImportPicker: UIViewControllerRepresentable {
    let completion: (Result<URL?, Error>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) { }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (Result<URL?, Error>) -> Void
        init(completion: @escaping (Result<URL?, Error>) -> Void) { self.completion = completion }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let first = urls.first else { completion(.failure(ImportError.invalidFile)); return }
            completion(.success(first))
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion(.success(nil))
        }
    }
}

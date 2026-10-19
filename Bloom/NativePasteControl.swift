import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Uses the system paste affordance and an explicit responder target, without polling the clipboard.
struct NativePasteControl: UIViewControllerRepresentable {
    let label: String
    let identifier: String
    let onPaste: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> PasteInputController { PasteInputController() }
    func updateUIViewController(_ controller: PasteInputController, context: Context) {
        controller.loadViewIfNeeded()
        controller.control.accessibilityLabel = label
        controller.control.accessibilityIdentifier = identifier
        controller.control.isUserInteractionEnabled = context.environment.isEnabled && !controller.loading
        controller.onPaste = onPaste; controller.onError = onError
    }
}

final class PasteInputController: UIViewController {
    let control: UIPasteControl = {
        let configuration = UIPasteControl.Configuration()
        configuration.displayMode = .iconOnly
        return UIPasteControl(configuration: configuration)
    }()
    var onPaste: (String) -> Void = { _ in }
    var onError: (String) -> Void = { _ in }
    private(set) var loading = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        pasteConfiguration = UIPasteConfiguration(acceptableTypeIdentifiers: [UTType.plainText.identifier, UTType.url.identifier])
        control.target = self
        control.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(control)
        NSLayoutConstraint.activate([
            control.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            control.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            control.widthAnchor.constraint(equalToConstant: 44),
            control.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    override func paste(itemProviders: [NSItemProvider]) {
        guard !loading, let provider = itemProviders.first else { return }
        loading = true; control.isUserInteractionEnabled = false
        if provider.canLoadObject(ofClass: NSString.self) {
            provider.loadObject(ofClass: NSString.self) { [weak self] object, error in
                let text = (object as? NSString).map { String($0) }
                Task { @MainActor [weak self] in self?.finish(text, error: error) }
            }
        } else if provider.canLoadObject(ofClass: NSURL.self) {
            provider.loadObject(ofClass: NSURL.self) { [weak self] object, error in
                let text = (object as? NSURL)?.absoluteString
                Task { @MainActor [weak self] in self?.finish(text, error: error) }
            }
        } else { finish(nil, error: nil) }
    }

    private func finish(_ text: String?, error: Error?) {
        loading = false; control.isUserInteractionEnabled = true
        guard viewIfLoaded?.window != nil else { return }
        if let text, !text.isEmpty { onPaste(text) }
        else { onError(error?.localizedDescription ?? "Non è stato possibile leggere il contenuto copiato. Puoi incollarlo nel campo Link.") }
    }
}

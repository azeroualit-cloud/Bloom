import UIKit
import UniformTypeIdentifiers

@MainActor
final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private var isSaving = false
    private var loadedURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        statusLabel.numberOfLines = 0
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.adjustsFontForContentSizeCategory = true
        retryButton.setTitle("Riprova", for: .normal)
        retryButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        cancelButton.setTitle("Annulla", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [statusLabel, retryButton, cancelButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            cancelButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        save()
    }

    @objc private func save() {
        guard !isSaving else { return }
        isSaving = true
        retryButton.isHidden = true
        cancelButton.isEnabled = false
        statusLabel.text = "Salvataggio in Bloom…"
        if let loadedURL { persist(loadedURL); return }
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        guard let provider = items.flatMap({ $0.attachments ?? [] }).first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }) else { fail(CaptureError.invalidURL); return }
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
            let url = (item as? URL) ?? (item as? String).flatMap(URL.init(string:))
            Task { @MainActor in
                guard let self else { return }
                if let error { self.fail(error) }
                else if let url { self.loadedURL = url; self.persist(url) }
                else { self.fail(CaptureError.invalidURL) }
            }
        }
    }

    private func persist(_ url: URL) {
        do {
            try CaptureInbox(root: CaptureInbox.sharedRoot()).save(url)
            statusLabel.text = "Salvato in Bloom"
            extensionContext?.completeRequest(returningItems: nil)
        } catch { fail(error) }
    }

    private func fail(_ error: Error) {
        isSaving = false
        statusLabel.text = error.localizedDescription
        retryButton.isHidden = false
        cancelButton.isEnabled = true
    }

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }
}

import SwiftUI
import UIKit

/// One editable document. Styling never rewrites the Markdown or resets the undo stack.
@MainActor
struct LiveMarkdownEditor: UIViewRepresentable {
    @Binding var text: String
    var query = ""
    @Binding var focused: Bool
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = UIColor(Color.bloomBackground)
        view.textColor = UIColor(Color.bloomText)
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        view.contentInsetAdjustmentBehavior = .never
        view.clipsToBounds = true
        view.textContainer.lineFragmentPadding = 0
        view.textContainerInset = UIEdgeInsets(top: BloomLayout.margin, left: BloomLayout.margin, bottom: BloomLayout.section, right: BloomLayout.margin)
        view.autocorrectionType = .yes
        view.smartQuotesType = .no; view.smartDashesType = .no
        view.accessibilityLabel = "Documento Markdown"
        view.accessibilityIdentifier = "pkms-editor"
        context.coordinator.editor = view
        view.text = text
        context.coordinator.installToolbar(view)
        context.coordinator.style(view)
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        var needsStyling = context.coordinator.lastQuery != query || context.coordinator.lastFontSize != UIFont.preferredFont(forTextStyle: .body).pointSize || context.coordinator.lastStyle != view.traitCollection.userInterfaceStyle
        if view.text != text && view.markedTextRange == nil {
            needsStyling = true
            let selection = view.selectedRange
            view.text = text
            view.selectedRange = NSRange(location: min(selection.location, view.text.utf16.count), length: 0)
        }
        if needsStyling, view.markedTextRange == nil { context.coordinator.style(view) }
        if context.coordinator.lastQuery != query {
            context.coordinator.lastQuery = query
            if !query.isEmpty, let range = view.text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
                view.scrollRangeToVisible(NSRange(range, in: view.text))
            }
        }
    }
    @MainActor final class Coordinator: NSObject, UITextViewDelegate {
        var parent: LiveMarkdownEditor
        weak var editor: UITextView?
        var lastQuery = ""
        var lastFontSize: CGFloat = 0
        var lastStyle: UIUserInterfaceStyle = .unspecified
        init(_ parent: LiveMarkdownEditor) { self.parent = parent }
        func textViewDidBeginEditing(_ textView: UITextView) { parent.focused = true }
        func textViewDidEndEditing(_ textView: UITextView) { parent.focused = false }
        func textViewDidChange(_ view: UITextView) {
            guard view.markedTextRange == nil else { return }
            parent.text = view.text
            let paragraph = (view.text as NSString).paragraphRange(for: NSRange(location: min(view.selectedRange.location, view.text.utf16.count), length: 0))
            style(view, range: paragraph)
        }
        func installToolbar(_ view: UITextView) {
            let bar = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 52))
            bar.autoresizingMask = [.flexibleWidth]
            bar.backgroundColor = UIColor(Color.bloomSurface)
            bar.accessibilityIdentifier = "pkms-formatting-bar"
            let formatting = UIMenu(title: "Formato Markdown", children: [
                UIAction(title: "Titolo", image: UIImage(systemName: "textformat.size")) { [weak self] _ in self?.heading() },
                UIAction(title: "Grassetto", image: UIImage(systemName: "bold")) { [weak self] _ in self?.bold() },
                UIAction(title: "Elenco", image: UIImage(systemName: "list.bullet")) { [weak self] _ in self?.bullet() },
                UIAction(title: "Checklist", image: UIImage(systemName: "checklist")) { [weak self] _ in self?.checklist() },
                UIAction(title: "Collegamento", image: UIImage(systemName: "link")) { [weak self] _ in self?.link() },
                UIAction(title: "Codice", image: UIImage(systemName: "chevron.left.forwardslash.chevron.right")) { [weak self] _ in self?.code() }
            ])
            let stack = UIStackView()
            stack.axis = .horizontal; stack.spacing = BloomLayout.compact
            stack.distribution = .fillEqually
            stack.translatesAutoresizingMaskIntoConstraints = false
            func action(_ symbol: String, _ label: String, _ perform: @escaping () -> Void) -> UIButton {
                let button = UIButton(type: .system)
                button.setImage(UIImage(systemName: symbol), for: .normal)
                button.accessibilityLabel = label
                button.addAction(UIAction { _ in perform() }, for: .touchUpInside)
                button.tintColor = UIColor(Color.bloomText)
                return button
            }
            let format = UIButton(type: .system)
            format.setImage(UIImage(systemName: "ellipsis"), for: .normal)
            format.accessibilityLabel = "Formato Markdown"
            format.menu = formatting; format.showsMenuAsPrimaryAction = true
            format.tintColor = UIColor(Color.bloomText)
            let done = UIButton(type: .system)
            done.setTitle("Fine", for: .normal)
            done.titleLabel?.font = .preferredFont(forTextStyle: .body)
            done.titleLabel?.adjustsFontForContentSizeCategory = true
            done.titleLabel?.adjustsFontSizeToFitWidth = true
            done.titleLabel?.minimumScaleFactor = 0.7
            done.setTitleColor(UIColor(Color.bloomBackground), for: .normal)
            done.backgroundColor = UIColor(Color.accentColor)
            done.layer.cornerRadius = BloomLayout.gap
            done.accessibilityLabel = "Chiudi tastiera"
            done.accessibilityIdentifier = "pkms-keyboard-done"
            done.addAction(UIAction { [weak self] _ in self?.hideKeyboard() }, for: .touchUpInside)
            [action("bold", "Grassetto", { [weak self] in self?.bold() }),
             action("list.bullet", "Elenco", { [weak self] in self?.bullet() }),
             action("checklist", "Checklist", { [weak self] in self?.checklist() }),
             action("link", "Collegamento", { [weak self] in self?.link() }), format, done].forEach(stack.addArrangedSubview)
            bar.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: BloomLayout.margin),
                stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -BloomLayout.margin),
                stack.topAnchor.constraint(equalTo: bar.topAnchor, constant: BloomLayout.compact),
                stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -BloomLayout.compact)
            ])
            view.inputAccessoryView = bar
        }
        @objc private func heading() { prefix("## ") }
        @objc private func bullet() { prefix("- ") }
        @objc private func checklist() { prefix("- [ ] ") }
        @objc private func bold() { wrap("**", "**") }
        @objc private func code() { wrap("`", "`") }
        @objc private func link() { wrap("[", "](https://)") }
        @objc private func hideKeyboard() { editor?.resignFirstResponder() }
        private func prefix(_ prefix: String) {
            guard let view = editor else { return }
            let range = (view.text as NSString).lineRange(for: NSRange(location: view.selectedRange.location, length: 0))
            view.selectedRange = NSRange(location: range.location, length: 0)
            view.insertText(prefix)
        }
        private func wrap(_ before: String, _ after: String) {
            guard let view = editor else { return }
            let range = view.selectedRange
            let selected = (view.text as NSString).substring(with: range)
            view.insertText(before + selected + after)
            view.selectedRange = NSRange(location: range.location + before.utf16.count, length: selected.utf16.count)
        }
        func style(_ view: UITextView, range: NSRange? = nil) {
            guard view.markedTextRange == nil else { return }
            let storage = view.textStorage, full = range ?? NSRange(location: 0, length: storage.length)
            let body = UIFont.preferredFont(forTextStyle: .body)
            lastFontSize = body.pointSize; lastStyle = view.traitCollection.userInterfaceStyle
            let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 3; paragraph.paragraphSpacing = 0
            storage.beginEditing()
            storage.setAttributes([.font: body, .foregroundColor: UIColor(Color.bloomText), .paragraphStyle: paragraph], range: full)
            let string = storage.string
            // Source mode deliberately shows literal Markdown without partial rich rendering.
            if !parent.query.isEmpty, let expression = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: parent.query), options: [.caseInsensitive]) {
                for match in expression.matches(in: string, range: full) { storage.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.3), range: match.range) }
            }
            storage.endEditing()
            view.typingAttributes = [.font: body, .foregroundColor: UIColor(Color.bloomText), .paragraphStyle: paragraph]
        }
    }
}

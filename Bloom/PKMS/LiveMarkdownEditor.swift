import SwiftUI
import UIKit

/// One editable document. Styling never rewrites the Markdown or resets the undo stack.
@MainActor
struct LiveMarkdownEditor: UIViewRepresentable {
    @Binding var text: String
    var query = ""
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
        view.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 40, right: 16)
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
        func textViewDidChange(_ view: UITextView) {
            guard view.markedTextRange == nil else { return }
            parent.text = view.text
            let paragraph = (view.text as NSString).paragraphRange(for: NSRange(location: min(view.selectedRange.location, view.text.utf16.count), length: 0))
            style(view, range: paragraph)
        }
        func installToolbar(_ view: UITextView) {
            let bar = UIToolbar()
            bar.items = [
                UIBarButtonItem(title: "H", style: .plain, target: self, action: #selector(heading)),
                UIBarButtonItem(image: UIImage(systemName: "bold"), style: .plain, target: self, action: #selector(bold)),
                UIBarButtonItem(image: UIImage(systemName: "list.bullet"), style: .plain, target: self, action: #selector(bullet)),
                UIBarButtonItem(image: UIImage(systemName: "checklist"), style: .plain, target: self, action: #selector(checklist)),
                UIBarButtonItem(image: UIImage(systemName: "link"), style: .plain, target: self, action: #selector(link)),
                UIBarButtonItem(image: UIImage(systemName: "chevron.left.forwardslash.chevron.right"), style: .plain, target: self, action: #selector(code)),
                UIBarButtonItem(systemItem: .flexibleSpace),
                UIBarButtonItem(image: UIImage(systemName: "keyboard.chevron.compact.down"), style: .plain, target: self, action: #selector(hideKeyboard))
            ]
            let labels = ["Titolo", "Grassetto", "Elenco", "Checklist", "Collegamento", "Codice", "", "Chiudi tastiera"]
            for (item, label) in zip(bar.items ?? [], labels) { item.accessibilityLabel = label }
            bar.sizeToFit(); view.inputAccessoryView = bar
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
            let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 5; paragraph.paragraphSpacing = 6
            storage.beginEditing()
            storage.setAttributes([.font: body, .foregroundColor: UIColor(Color.bloomText), .paragraphStyle: paragraph], range: full)
            let string = storage.string
            func apply(_ pattern: String, _ attributes: [NSAttributedString.Key: Any]) {
                guard let expression = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
                for match in expression.matches(in: string, range: full) { storage.addAttributes(attributes, range: match.range) }
            }
            apply("^#{1,6} .+$", [.font: UIFont.preferredFont(forTextStyle: .title2), .foregroundColor: UIColor(Color.bloomText)])
            apply("\\*\\*[^\\n]+?\\*\\*", [.font: UIFont.boldSystemFont(ofSize: body.pointSize)])
            apply("(?<!\\*)\\*[^*\\n]+\\*(?!\\*)", [.font: UIFont.italicSystemFont(ofSize: body.pointSize)])
            apply("~~[^~\\n]+~~", [.strikethroughStyle: NSUnderlineStyle.single.rawValue])
            apply("`[^`\\n]+`", [.font: UIFont.monospacedSystemFont(ofSize: body.pointSize, weight: .regular), .backgroundColor: UIColor(Color.bloomSurface)])
            apply("^>.*$", [.foregroundColor: UIColor.secondaryLabel])
            apply("^[ \\t]*[-*+] \\[[ xX]\\]", [.foregroundColor: UIColor(Color.accentColor)])
            apply("\\[[^\\]\\n]+\\]\\([^\\)\\n]+\\)", [.foregroundColor: UIColor(Color.accentColor)])
            if !parent.query.isEmpty, let expression = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: parent.query), options: [.caseInsensitive]) {
                for match in expression.matches(in: string, range: full) { storage.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.3), range: match.range) }
            }
            storage.endEditing()
            view.typingAttributes = [.font: body, .foregroundColor: UIColor(Color.bloomText), .paragraphStyle: paragraph]
        }
    }
}

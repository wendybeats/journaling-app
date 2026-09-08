// The living writing surface — per-line type. Each line is classified by
// its own content (WrittenScale), so pressing Enter *preserves* a line at
// the size it was written: leave "Focus" on its own line and it stays 40
// forever while the paragraph below breathes independently down to body.
// Only the line the caret lives on ever changes size.
//
// One SwiftUI TextField can't hold mixed sizes, so this is a UITextView
// with per-line attributes — the same single-text-engine move as the
// notebook's drop caps (DropCapBody).

import SwiftUI
import UIKit

struct LivingWriteView: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    /// The first-word hook (QA 2026-09-05): while true, the view keeps
    /// receiving keystrokes but paints its text and caret clear — the
    /// page shows the large centered overlay word instead, and the seat
    /// animation ends by flipping this off to reveal the real text.
    var concealed = false

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.tintColor = concealed ? .clear : UIColor(Tokens.Line.cursor)
        tv.delegate = context.coordinator
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        context.coordinator.concealed = concealed
        Self.applyAssist(tv, concealed: concealed)
        Self.restyle(tv, to: text, caretToEnd: true, concealed: concealed)   // a restored draft opens ready to continue
        return tv
    }

    /// Autocorrect, spell-check and inline predictions anchor their
    /// bubbles to the REAL text — top-left, invisible — while the hook's
    /// overlay word sits centered (QA 2026-09-08: a stray "He ×" bubble
    /// and marked-text box). They sleep while concealed and wake on the
    /// reveal; reloadInputViews makes the keyboard honor the change
    /// mid-session.
    private static func applyAssist(_ tv: UITextView, concealed: Bool) {
        tv.autocorrectionType = concealed ? .no : .default
        tv.spellCheckingType = concealed ? .no : .default
        if #available(iOS 17.0, *) {
            tv.inlinePredictionType = concealed ? .no : .default
        }
        if tv.isFirstResponder { tv.reloadInputViews() }
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.concealed != concealed {
            context.coordinator.concealed = concealed
            tv.tintColor = concealed ? .clear : UIColor(Tokens.Line.cursor)
            Self.applyAssist(tv, concealed: concealed)
            Self.restyle(tv, concealed: concealed)
            if !concealed {
                // The caret doesn't repaint on a tint change alone — nudge
                // the selection so it reappears at the end of the text
                // the moment the overlay word seats (QA 2026-09-06).
                let end = NSRange(location: (tv.text as NSString).length, length: 0)
                tv.selectedRange = NSRange(location: 0, length: 0)
                tv.selectedRange = end
                tv.setNeedsDisplay()
            }
        }
        if tv.text != text {
            // Text arriving from outside the keyboard (dictation partials,
            // the post-commit clear) writes at the end — the caret rides
            // ahead of it, never stranded behind mid-text.
            Self.restyle(tv, to: text, caretToEnd: true, concealed: concealed)
        }
        if focused, !tv.isFirstResponder {
            tv.becomeFirstResponder()
        } else if !focused, tv.isFirstResponder {
            tv.resignFirstResponder()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width - Tokens.Space.screenX * 2
        let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        // Never collapse below one empty line at the meeting size.
        let floor = WrittenFormat.uiFont(28).lineHeight
        return CGSize(width: width, height: max(fit.height, floor))
    }

    // MARK: Styling

    /// The rendering width the format measures against — the live text
    /// container when laid out, the page width before that.
    private static func measureWidth(_ tv: UITextView) -> CGFloat {
        let w = tv.textContainer.size.width
        return w > 40 ? w : WrittenFormat.pageWidth
    }

    /// Re-derives the whole format (first word large, measured first line
    /// medium, body after, bullets italic — WrittenFormat, QA 2026-09-06),
    /// preserving the caret. Skipped while marked text is in flight (CJK
    /// composition, dictation marks).
    static func restyle(_ tv: UITextView, to newText: String? = nil, caretToEnd: Bool = false, concealed: Bool = false) {
        guard tv.markedTextRange == nil else {
            if let newText, tv.text != newText { tv.text = newText }
            return
        }
        let string = newText ?? tv.text ?? ""
        let ns = string as NSString
        let caret = caretToEnd
            ? NSRange(location: ns.length, length: 0)
            : tv.selectedRange
        tv.attributedText = WrittenFormat.attributed(string, width: measureWidth(tv), concealed: concealed)
        tv.selectedRange = NSRange(location: min(caret.location, ns.length), length: 0)
        syncTypingAttributes(tv, concealed: concealed)
    }

    /// Typing attributes follow the caret's tier, so a fresh character
    /// arrives at the right size before the restyle pass.
    static func syncTypingAttributes(_ tv: UITextView, concealed: Bool = false) {
        let text = tv.text ?? ""
        let pos = min(tv.selectedRange.location, (text as NSString).length)
        let tier = WrittenFormat.tier(at: max(0, pos - 1), in: text, width: measureWidth(tv))
        tv.typingAttributes = WrittenFormat.attributes(for: tier, concealed: concealed)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: LivingWriteView
        var concealed = false
        init(_ parent: LivingWriteView) { self.parent = parent }

        func textViewDidChange(_ tv: UITextView) {
            LivingWriteView.restyle(tv, concealed: concealed)
            let value = tv.text ?? ""
            DispatchQueue.main.async { self.parent.text = value }
        }

        func textViewDidChangeSelection(_ tv: UITextView) {
            LivingWriteView.syncTypingAttributes(tv, concealed: concealed)
        }

        /// The list assists (QA 2026-09-06): "- " at a line start becomes
        /// "• "; Enter on a bullet line continues the list; Enter on an
        /// empty bullet removes the marker and ends it.
        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange,
                      replacementText t: String) -> Bool {
            let ns = (tv.text ?? "") as NSString
            guard range.location <= ns.length, tv.markedTextRange == nil else { return true }

            if t == " ", range.length == 0, range.location >= 1 {
                let lr = ns.lineRange(for: NSRange(location: range.location - 1, length: 0))
                let beforeCaret = ns.substring(
                    with: NSRange(location: lr.location, length: range.location - lr.location))
                if beforeCaret.trimmingCharacters(in: .whitespaces) == "-",
                   beforeCaret.hasSuffix("-") {
                    tv.textStorage.replaceCharacters(
                        in: NSRange(location: range.location - 1, length: 1), with: "•")
                    // Same length — the pending space still lands where it was.
                }
                return true
            }

            if t == "\n", range.length == 0 {
                let lr = ns.lineRange(for: NSRange(location: range.location, length: 0))
                let lineLen = max(0, min(lr.length, ns.length - lr.location))
                let line = ns.substring(with: NSRange(location: lr.location, length: lineLen))
                    .trimmingCharacters(in: .newlines)
                let stripped = line.trimmingCharacters(in: .whitespaces)
                if stripped == "•" || stripped == "• " {
                    // Empty bullet: Enter ends the list — the marker leaves.
                    tv.textStorage.replaceCharacters(
                        in: NSRange(location: lr.location, length: (line as NSString).length), with: "")
                    tv.selectedRange = NSRange(location: lr.location, length: 0)
                    finishManualEdit(tv)
                    return false
                }
                if stripped.hasPrefix("• ") {
                    tv.textStorage.replaceCharacters(in: range, with: "\n• ")
                    tv.selectedRange = NSRange(location: range.location + 3, length: 0)
                    finishManualEdit(tv)
                    return false
                }
            }
            return true
        }

        private func finishManualEdit(_ tv: UITextView) {
            LivingWriteView.restyle(tv, concealed: concealed)
            let value = tv.text ?? ""
            DispatchQueue.main.async { self.parent.text = value }
        }

        func textViewDidBeginEditing(_ tv: UITextView) {
            DispatchQueue.main.async { self.parent.focused = true }
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            DispatchQueue.main.async { self.parent.focused = false }
        }
    }
}

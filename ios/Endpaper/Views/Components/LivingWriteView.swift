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

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.tintColor = UIColor(Tokens.Line.cursor)
        tv.delegate = context.coordinator
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        Self.restyle(tv, to: text, caretToEnd: true)   // a restored draft opens ready to continue
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self
        if tv.text != text {
            // Text arriving from outside the keyboard (dictation partials,
            // the post-commit clear) writes at the end — the caret rides
            // ahead of it, never stranded behind mid-text.
            Self.restyle(tv, to: text, caretToEnd: true)
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
        let floor = Self.font(28).lineHeight
        return CGSize(width: width, height: max(fit.height, floor))
    }

    // MARK: Styling

    private static func font(_ size: CGFloat) -> UIFont {
        UIFont(name: EndpaperFont.body, size: size) ?? .systemFont(ofSize: size)
    }

    private static func attributes(forLine line: String) -> [NSAttributedString.Key: Any] {
        let size = WrittenScale.size(for: line)
        let font = font(size)
        let lh: CGFloat = size >= 36 ? 1.25 : (size >= 22 ? 1.5 : 1.8)
        let para = NSMutableParagraphStyle()
        para.lineSpacing = max(0, size * lh - font.lineHeight)
        // The largest tier gets air above and below — a big word idea
        // shouldn't sit shoulder-to-shoulder with its neighbors.
        if size >= 36 {
            para.paragraphSpacingBefore = 12
            para.paragraphSpacing = 8
        }
        return [
            .font: font,
            .paragraphStyle: para,
            .foregroundColor: UIColor(Tokens.Text.written),
        ]
    }

    /// Re-derives every line's attributes, preserving the caret. Skipped
    /// while marked text is in flight (CJK composition, dictation marks).
    static func restyle(_ tv: UITextView, to newText: String? = nil, caretToEnd: Bool = false) {
        guard tv.markedTextRange == nil else {
            if let newText, tv.text != newText { tv.text = newText }
            return
        }
        let string = newText ?? tv.text ?? ""
        let ns = string as NSString
        let caret = caretToEnd
            ? NSRange(location: ns.length, length: 0)
            : tv.selectedRange
        let attr = NSMutableAttributedString(string: string)
        var loc = 0
        for line in string.components(separatedBy: "\n") {
            let len = (line as NSString).length
            attr.addAttributes(attributes(forLine: line),
                               range: NSRange(location: loc, length: len))
            loc += len + 1
        }
        tv.attributedText = attr
        tv.selectedRange = NSRange(location: min(caret.location, ns.length), length: 0)
        syncTypingAttributes(tv)
    }

    /// Typing attributes follow the caret's line, so a fresh character on
    /// a fresh line arrives at the right size before the restyle pass.
    static func syncTypingAttributes(_ tv: UITextView) {
        let ns = (tv.text ?? "") as NSString
        let pos = min(tv.selectedRange.location, ns.length)
        let lineRange = ns.lineRange(for: NSRange(location: pos, length: 0))
        let line = ns.substring(with: lineRange)
            .trimmingCharacters(in: .newlines)
        tv.typingAttributes = attributes(forLine: line)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: LivingWriteView
        init(_ parent: LivingWriteView) { self.parent = parent }

        func textViewDidChange(_ tv: UITextView) {
            LivingWriteView.restyle(tv)
            let value = tv.text ?? ""
            DispatchQueue.main.async { self.parent.text = value }
        }

        func textViewDidChangeSelection(_ tv: UITextView) {
            LivingWriteView.syncTypingAttributes(tv)
        }

        func textViewDidBeginEditing(_ tv: UITextView) {
            DispatchQueue.main.async { self.parent.focused = true }
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            DispatchQueue.main.async { self.parent.focused = false }
        }
    }
}

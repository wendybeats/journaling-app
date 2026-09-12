// The glimpse highlight on the page (QA 2026-09-12): a soft wash behind
// one word inside a UITextView, tight to the glyph line (the paragraph's
// line spacing is NOT part of it), drawn left→right with an ease-out on
// arrival, repositioned silently as the text reflows. Tapping the word
// opens the dialogue. Used by the live editor and by the read-only
// section view below.

import SwiftUI
import UIKit

final class GlimpseWashView: UIView {
    private let fill = UIView()
    /// Identity of the glimpse being shown — a new one animates in, the
    /// same one only repositions.
    private(set) var identity: String = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        fill.layer.cornerRadius = 3
        fill.backgroundColor = UIColor(Tokens.Text.written).withAlphaComponent(0.16)
        addSubview(fill)
    }
    required init?(coder: NSCoder) { nil }

    func place(at rect: CGRect, identity: String) {
        let fresh = identity != self.identity
        self.identity = identity
        frame = rect
        if fresh {
            fill.frame = CGRect(x: 0, y: 0, width: 0, height: rect.height)
            UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseOut]) {
                self.fill.frame = self.bounds
            }
        } else {
            fill.frame = bounds
        }
    }

    /// The word's rect in the text view's coordinates — the glyph run's
    /// horizontal extent, the run's font height vertically.
    static func rect(for range: NSRange, in tv: UITextView) -> CGRect? {
        let lm = tv.layoutManager
        lm.ensureLayout(for: tv.textContainer)
        let glyphs = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var r = lm.boundingRect(forGlyphRange: glyphs, in: tv.textContainer)
        guard !r.isNull, r.width > 0 else { return nil }
        let length = tv.attributedText?.length ?? 0
        let font = (range.location < length
                    ? tv.attributedText?.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
                    : nil) ?? WrittenFormat.uiFont(WrittenFormat.body)
        r.size.height = font.lineHeight
        r = r.insetBy(dx: -3, dy: -1)
        r.origin.x += tv.textContainerInset.left
        r.origin.y += tv.textContainerInset.top
        return r
    }

    /// Show, move, or remove the wash for `forms` in `tv`. Returns the
    /// range lit, if any.
    @discardableResult
    static func sync(in tv: UITextView, forms: [String]?, stored: inout GlimpseWashView?) -> NSRange? {
        guard let forms, !forms.isEmpty,
              let range = Glimpse.lastNSRange(of: forms, in: tv.text ?? ""),
              let rect = rect(for: range, in: tv) else {
            stored?.removeFromSuperview()
            stored = nil
            return nil
        }
        let wash: GlimpseWashView
        if let existing = stored {
            wash = existing
        } else {
            wash = GlimpseWashView(frame: rect)
            tv.insertSubview(wash, at: 0)   // beneath the text
            stored = wash
        }
        wash.place(at: rect, identity: forms.sorted().joined(separator: "|"))
        return range
    }
}

/// A committed section carrying the glimpse: the same WrittenFormat
/// rendering as the SwiftUI Text, in a read-only UITextView so the wash
/// can be placed on the word. Tap anywhere on the lit word opens the
/// dialogue.
struct WashedTextView: UIViewRepresentable {
    let text: String
    let forms: [String]
    var onTap: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tv.addGestureRecognizer(tap)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.onTap = onTap
        let width = tv.bounds.width > 40 ? tv.bounds.width : WrittenFormat.pageWidth
        let attributed = WrittenFormat.attributed(text, width: width)
        if tv.attributedText != attributed { tv.attributedText = attributed }
        context.coordinator.range = GlimpseWashView.sync(in: tv, forms: forms, stored: &context.coordinator.wash)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? WrittenFormat.pageWidth
        let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fit.height)
    }

    final class Coordinator: NSObject {
        var onTap: (() -> Void)?
        var wash: GlimpseWashView? = nil
        var range: NSRange? = nil
        init(onTap: (() -> Void)?) { self.onTap = onTap }

        @objc func tapped(_ g: UITapGestureRecognizer) {
            guard let wash, let tv = g.view else { return }
            let p = g.location(in: tv)
            if wash.frame.insetBy(dx: -12, dy: -12).contains(p) { onTap?() }
        }
    }
}

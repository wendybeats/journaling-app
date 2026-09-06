// The simplified written format (QA 2026-09-06, rev. 2): the original
// per-line resizing, reduced to three moves and never mixed on a line.
// A lone word is LARGE; once the line has more words it becomes MEDIUM
// as a whole, for as long as it genuinely fits one rendered line at
// medium (measured, not guessed from a character count); the moment it
// would wrap, the whole line is BODY. Only the first line of a block
// resizes — the lines after it are body, and a blank line starts the
// next block. Bullet lines ("- " converts to "• " as you type) are body
// size, italic, and hold the block at body until a blank line.
// WrittenScale stays untouched for the reflections heuristics and the
// JS parity suite; this is the display grammar.

import SwiftUI
import UIKit

enum WrittenFormat {
    static let large: CGFloat = 34
    static let medium: CGFloat = 22
    static let body: CGFloat = 17

    enum Tier {
        case large, medium, body, bullet
        var size: CGFloat {
            switch self {
            case .large: return WrittenFormat.large
            case .medium: return WrittenFormat.medium
            case .body, .bullet: return WrittenFormat.body
            }
        }
        var italic: Bool { self == .bullet }
    }

    struct Segment {
        let text: String
        let tier: Tier
    }

    /// The width both surfaces render at (screen minus the page margins) —
    /// the writing view passes its real container width when it has one.
    static var pageWidth: CGFloat {
        UIScreen.main.bounds.width - Tokens.Space.screenX * 2
    }

    static func uiFont(_ size: CGFloat, italic: Bool = false) -> UIFont {
        if italic {
            if let f = UIFont(name: "Newsreader-Italic", size: size) { return f }
            if let base = UIFont(name: EndpaperFont.body, size: size),
               let desc = base.fontDescriptor.withSymbolicTraits(.traitItalic) {
                return UIFont(descriptor: desc, size: size)
            }
        }
        return UIFont(name: EndpaperFont.body, size: size) ?? .systemFont(ofSize: size)
    }

    static func isBulletLine(_ line: some StringProtocol) -> Bool {
        let t = line.drop(while: { $0 == " " })
        return t.hasPrefix("• ") || t.hasPrefix("- ") || t == "•" || t == "-"
    }

    // MARK: Segmentation — one tier per LINE, never mixed on a line

    /// Contiguous segments covering `text` exactly, one per typed line
    /// (newlines ride with the following line's segment). Lines are sized
    /// whole: a lone word is large; a line that fits at medium is medium;
    /// a line that would wrap at medium is body. Within a block (lines
    /// between blank lines) only the FIRST non-bullet line resizes — what
    /// follows it is body, and anything following a bullet stays body
    /// until a blank line starts a new block. That blank line is the
    /// "two returns after a list" that brings the large line back.
    static func segments(for text: String, width: CGFloat) -> [Segment] {
        guard !text.isEmpty else { return [] }
        var segs: [Segment] = []
        var heroUsed = false          // this block's resizing line is spent

        var rest = Substring(text)
        var first = true
        while first || !rest.isEmpty {
            let lineEnd = first
                ? (rest.firstIndex(of: "\n") ?? rest.endIndex)
                : (rest.dropFirst().firstIndex(of: "\n") ?? rest.endIndex)
            let chunk = String(rest[..<lineEnd])        // ("\n" +) the line
            let line = first ? chunk : String(chunk.dropFirst())

            let tier: Tier
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                heroUsed = false                        // blank line: new block
                tier = .body
            } else if isBulletLine(line) {
                heroUsed = true                         // a list pins the block to body
                tier = .bullet
            } else if !heroUsed {
                heroUsed = true
                tier = heroTier(for: line, width: width)
            } else {
                tier = .body
            }
            segs.append(Segment(text: chunk, tier: tier))

            rest = rest[lineEnd...]
            first = false
        }
        return merged(segs)
    }

    /// The block's resizing line: a lone short word is large; a line that
    /// genuinely fits one rendered line at medium is medium; the moment
    /// medium would wrap, the whole line is body.
    private static func heroTier(for line: String, width: CGFloat) -> Tier {
        let t = line.trimmingCharacters(in: .whitespaces)
        let words = t.split(whereSeparator: { $0.isWhitespace })
        if words.count == 1 && t.count <= 18 { return .large }
        return fitsOneLine(t, at: medium, width: width) ? .medium : .body
    }

    private static func fitsOneLine(_ line: String, at size: CGFloat, width: CGFloat) -> Bool {
        let font = uiFont(size)
        let h = NSAttributedString(string: line, attributes: [.font: font])
            .boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                          options: [.usesLineFragmentOrigin, .usesFontLeading],
                          context: nil).height
        return h <= font.lineHeight + 1
    }

    private static func merged(_ segs: [Segment]) -> [Segment] {
        segs.reduce(into: [Segment]()) { out, seg in
            if seg.text.isEmpty { return }
            if let last = out.last, last.tier == seg.tier {
                out[out.count - 1] = Segment(text: last.text + seg.text, tier: seg.tier)
            } else {
                out.append(seg)
            }
        }
    }

    /// The tier under a UTF-16 offset — drives the writing view's typing
    /// attributes so a fresh character arrives at the right size.
    static func tier(at offset: Int, in text: String, width: CGFloat) -> Tier {
        var loc = 0
        for seg in segments(for: text, width: width) {
            loc += (seg.text as NSString).length
            if offset < loc { return seg.tier }
        }
        return segments(for: text, width: width).last?.tier ?? .body
    }

    // MARK: UIKit rendering (the writing surface)

    static func attributes(for tier: Tier, concealed: Bool = false) -> [NSAttributedString.Key: Any] {
        let font = uiFont(tier.size, italic: tier.italic)
        let lh: CGFloat = tier.size >= 30 ? 1.25 : (tier.size >= 22 ? 1.5 : 1.8)
        let para = NSMutableParagraphStyle()
        para.lineSpacing = max(0, tier.size * lh - font.lineHeight)
        if tier == .bullet {
            para.headIndent = 14   // wrapped bullet lines align past the marker
        }
        return [
            .font: font,
            .paragraphStyle: para,
            .foregroundColor: concealed ? UIColor.clear : UIColor(Tokens.Text.written),
        ]
    }

    static func attributed(_ text: String, width: CGFloat, concealed: Bool = false) -> NSAttributedString {
        let attr = NSMutableAttributedString()
        for seg in segments(for: text, width: width) {
            attr.append(NSAttributedString(string: seg.text,
                                           attributes: attributes(for: seg.tier, concealed: concealed)))
        }
        return attr
    }

    // MARK: SwiftUI rendering (committed sections, notebook)

    /// One concatenated Text carrying the whole grammar — apply
    /// `.typeWrittenScaled(WrittenFormat.body)` outside for color and the
    /// body line rhythm; per-run fonts here win over the outer modifier.
    static func text(for string: String, width: CGFloat = WrittenFormat.pageWidth) -> Text {
        segments(for: string, width: width).reduce(Text(verbatim: "")) { acc, seg in
            var t = Text(verbatim: seg.text)
                .font(.custom(EndpaperFont.body, size: seg.tier.size))
            if seg.tier.italic { t = t.italic() }
            return acc + t
        }
    }
}

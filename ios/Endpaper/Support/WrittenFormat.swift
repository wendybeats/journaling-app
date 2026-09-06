// The simplified written format (QA 2026-09-06): the first word LARGE,
// the rest of the first VISUAL line MEDIUM, body from there on. The
// medium→body break is MEASURED — it falls exactly where the medium
// text itself would wrap at the page's width, not where a character
// count guesses smaller text would (the old classifier's tell).
// Bullet lines ("- " converts to "• " as you type) always render at
// body size, italic. WrittenScale stays untouched for the reflections
// heuristics and the JS parity suite; this is the display grammar.

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

    // MARK: Segmentation

    /// Contiguous segments covering `text` exactly (newlines ride with the
    /// following line's segment).
    static func segments(for text: String, width: CGFloat) -> [Segment] {
        guard !text.isEmpty else { return [] }
        var segs: [Segment] = []

        let firstBreak = text.firstIndex(of: "\n")
        let firstLine = firstBreak.map { String(text[..<$0]) } ?? text
        let tail = firstBreak.map { String(text[$0...]) } ?? ""

        if isBulletLine(firstLine) {
            segs.append(Segment(text: firstLine, tier: .bullet))
        } else if firstLine.trimmingCharacters(in: .whitespaces).isEmpty {
            if !firstLine.isEmpty { segs.append(Segment(text: firstLine, tier: .body)) }
        } else {
            segs.append(contentsOf: heroSegments(for: firstLine, width: width))
        }

        // Every later line: bullet or body.
        var rest = Substring(tail)
        while !rest.isEmpty {
            let lineEnd = rest.dropFirst().firstIndex(of: "\n") ?? rest.endIndex
            let chunk = String(rest[..<lineEnd])          // "\n" + the line
            segs.append(Segment(text: chunk, tier: isBulletLine(chunk.dropFirst()) ? .bullet : .body))
            rest = rest[lineEnd...]
        }
        return merged(segs)
    }

    /// First word large; then as many following words as genuinely fit on
    /// the same rendered line at medium; the overflow is body.
    private static func heroSegments(for line: String, width: CGFloat) -> [Segment] {
        let lead = line.prefix(while: { $0.isWhitespace })
        let afterLead = line[lead.endIndex...]
        let word = afterLead.prefix(while: { !$0.isWhitespace })
        let largeText = String(lead) + String(word)
        var rest = afterLead[word.endIndex...]

        var mediumText = ""
        while !rest.isEmpty {
            let space = rest.prefix(while: { $0.isWhitespace && $0 != "\n" })
            let next = rest[space.endIndex...].prefix(while: { !$0.isWhitespace })
            guard !next.isEmpty else { break }
            let candidate = mediumText + String(space) + String(next)
            guard fitsOneLine(large: largeText, medium: candidate, width: width) else { break }
            mediumText = candidate
            rest = rest[next.endIndex...]
        }

        var segs = [Segment(text: largeText, tier: .large)]
        if !mediumText.isEmpty { segs.append(Segment(text: mediumText, tier: .medium)) }
        if !rest.isEmpty { segs.append(Segment(text: String(rest), tier: .body)) }
        return segs
    }

    private static func fitsOneLine(large: String, medium: String, width: CGFloat) -> Bool {
        let a = NSMutableAttributedString(string: large, attributes: [.font: uiFont(Self.large)])
        a.append(NSAttributedString(string: medium, attributes: [.font: uiFont(Self.medium)]))
        let h = a.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                               options: [.usesLineFragmentOrigin, .usesFontLeading],
                               context: nil).height
        return h <= uiFont(Self.large).lineHeight + 1
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

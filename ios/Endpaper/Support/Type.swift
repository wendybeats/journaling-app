// Endpaper — the three type registers, ported from the token sheet.
//   heading → Instrument Sans (grotesk stand-in; Söhne is the target)
//   written → Newsreader 17 / 1.8 (line height is load-bearing; never below 1.7)
//   meta    → Fragment Mono 11 / 0.14em, uppercase
// Fonts are the same OFL files the web prototype ships, bundled as variable
// TTFs and registered via UIAppFonts.

import SwiftUI
import UIKit

enum EndpaperFont {
    static let heading = "Instrument Sans"
    static let body = "Newsreader"
    static let meta = "Fragment Mono"
}

/// SwiftUI's `lineSpacing` is *added* to the font's natural line height, so a
/// CSS line-height multiple has to be converted against the real font metrics.
private func spacing(family: String, size: CGFloat, lineHeight: CGFloat) -> CGFloat {
    let natural = UIFont(name: family, size: size)?.lineHeight ?? size * 1.2
    return max(0, size * lineHeight - natural)
}

// MARK: - Register modifiers (views use these, never raw fonts/sizes)

struct TypeDisplay: ViewModifier {          // 32 / 1.1 / 500 / -0.01em
    func body(content: Content) -> some View {
        content
            .font(.custom(EndpaperFont.heading, size: 32).weight(.medium))
            .tracking(32 * -0.01)
            .lineSpacing(spacing(family: EndpaperFont.heading, size: 32, lineHeight: 1.1))
            .foregroundStyle(Tokens.Text.heading)
    }
}

struct TypeTitle: ViewModifier {            // 22 / 1.2 / 500 / -0.005em
    func body(content: Content) -> some View {
        content
            .font(.custom(EndpaperFont.heading, size: 22).weight(.medium))
            .tracking(22 * -0.005)
            .lineSpacing(spacing(family: EndpaperFont.heading, size: 22, lineHeight: 1.2))
            .foregroundStyle(Tokens.Text.heading)
    }
}

struct TypeWritten: ViewModifier {          // 17 / 1.8 — the writing register
    var large = false                       // written-large: 18 / 1.75
    func body(content: Content) -> some View {
        let size: CGFloat = large ? 18 : 17
        let lh: CGFloat = large ? 1.75 : 1.8
        return content
            .font(.custom(EndpaperFont.body, size: size))
            .lineSpacing(spacing(family: EndpaperFont.body, size: size, lineHeight: lh))
            .foregroundStyle(Tokens.Text.written)
    }
}

struct TypeMeta: ViewModifier {             // 11 / 1.4 / 0.14em, uppercase
    var small = false                       // meta-small: 10
    func body(content: Content) -> some View {
        let size: CGFloat = small ? 10 : 11
        return content
            .font(.custom(EndpaperFont.meta, size: size))
            .tracking(size * 0.14)
            .textCase(.uppercase)
            .foregroundStyle(Tokens.Text.meta)
    }
}

extension View {
    func typeDisplay() -> some View { modifier(TypeDisplay()) }
    func typeTitle() -> some View { modifier(TypeTitle()) }
    func typeWritten(large: Bool = false) -> some View { modifier(TypeWritten(large: large)) }
    func typeMeta() -> some View { modifier(TypeMeta()) }
    func typeMetaSmall() -> some View { modifier(TypeMeta(small: true)) }
}

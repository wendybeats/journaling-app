// Endpaper — Design Tokens (Stage 0), ported 1:1 from styles/tokens.css.
// Source of truth: docs/endpaper-design-tokens.md
// Rule: views never reference raw hex or raw point sizes — only the
// semantic tokens defined here. Light/dark resolve at the token level,
// exactly as the CSS does with prefers-color-scheme.

import SwiftUI
import UIKit

// MARK: - Hex plumbing (file-private; primitives never leave this file)

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private func dynamic(light: UInt32, dark: UInt32) -> Color {
    Color(UIColor { traits in
        UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
    })
}

// MARK: - 1.1 Primitives (never used by views directly)

private enum Primitive {
    static let bone: UInt32        = 0xE8E6E1
    static let boneRaised: UInt32  = 0xEFEDE8
    static let ink: UInt32         = 0x1A1A1A
    static let inkSoft: UInt32     = 0x262320   // written text — a step off full ink
    static let boneSoft: UInt32    = 0xDEDAD3   // written text, dark mode
    static let graphite: UInt32    = 0x4A4843
    static let stone: UInt32       = 0xA9A6A0
    static let hairline: UInt32    = 0xC9C6BF
    static let char: UInt32        = 0x161514
    static let charRaised: UInt32  = 0x201F1D
    static let boneType: UInt32    = 0xE8E6E1
    static let graphiteDk: UInt32  = 0xB8B5AE
    static let stoneDk: UInt32     = 0x6B6862
    static let hairlineDk: UInt32  = 0x332F2B
}

// MARK: - Semantic tokens

enum Tokens {

    // 1.2 Semantic colors — one value per mode, resolved by the system.
    enum Surface {
        static let page     = dynamic(light: Primitive.bone,       dark: Primitive.char)
        static let raised   = dynamic(light: Primitive.boneRaised, dark: Primitive.charRaised)
        static let inverted = dynamic(light: Primitive.ink,        dark: Primitive.boneType)
    }

    enum Text {
        static let written    = dynamic(light: Primitive.inkSoft,    dark: Primitive.boneSoft)
        static let heading    = dynamic(light: Primitive.graphite,   dark: Primitive.graphiteDk)
        static let meta       = dynamic(light: Primitive.stone,      dark: Primitive.stoneDk)
        static let onInverted = dynamic(light: Primitive.boneRaised, dark: Primitive.ink)
    }

    enum Dot {
        static let filled = dynamic(light: Primitive.ink,      dark: Primitive.boneType)
        static let empty  = dynamic(light: Primitive.hairline, dark: Primitive.stoneDk)
        static let today  = dynamic(light: Primitive.ink,      dark: Primitive.boneType)
    }

    enum Line {
        static let rule   = dynamic(light: Primitive.hairline, dark: Primitive.hairlineDk)
        static let cursor = dynamic(light: Primitive.ink,      dark: Primitive.boneType)
    }

    // 3. Spacing
    enum Space {
        static let xs: CGFloat      = 6
        static let sm: CGFloat      = 10
        static let md: CGFloat      = 22
        static let lg: CGFloat      = 34   // between entries; day rule below — a floor, not a target
        static let xl: CGFloat      = 44   // screen top padding; before the dot grid
        static let xxl: CGFloat     = 48
        static let screenX: CGFloat = 28
        static let card: CGFloat    = 22
    }

    // 4. Radii & lines. No shadows in the system — elevation = Surface.raised tint only.
    enum Radius {
        static let card: CGFloat    = 14
        static let control: CGFloat = 8
        static let pill: CGFloat    = 999
    }
    static let lineWeight: CGFloat = 1

    // 5. Dots
    enum DotSize {
        static let base: CGFloat       = 7
        static let today: CGFloat      = 11
        static let todayRing: CGFloat  = 1.5
        static let todayRingOffset: CGFloat = 2
        static let gap: CGFloat        = 12
        static let gridCols            = 7
        static let year: CGFloat       = 5
        static let gapYear: CGFloat    = 6
        static let week: CGFloat       = 36   // large register: weekly breakdown, tappable
        static let weekToday: CGFloat  = 44
        static let gapWeek: CGFloat    = 18
    }

    // 6. Motion — cubic-bezier(0.22, 0.61, 0.36, 1) at 180 / 260 ms
    enum Motion {
        static let fast = Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.18)
        static let base = Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.26)
        static let fastDuration: TimeInterval = 0.18
        static let baseDuration: TimeInterval = 0.26
    }
}

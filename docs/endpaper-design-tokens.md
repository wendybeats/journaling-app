# Endpaper — Design Tokens (Stage 0)

**Version:** 1.1 — written register softened to `ink-soft`/`bone-soft` and bumped to 17px (July 5 review)
**Date:** July 5, 2026
**Scope:** Foundational design primitives — the single source of truth for every color, type, spacing, and motion value in the product. Everything downstream (Figma variables, SwiftUI, App Store assets) resolves to these tokens.

**How to use this file:**
- In Figma: create these as Variables (Color / Number / String collections), with light + dark modes on the color collection.
- In SwiftUI: mirror as a `Theme` enum / `Color` + `Font` extension set. Naming below is Swift-friendly (semantic, not raw hex references in views).
- Rule: **views never reference raw hex or raw point sizes — only semantic tokens.** A view uses `Endpaper.text.written`, never `#1A1A1A`.

---

## 1. Color

Two layers: a small primitive palette (raw values, never used directly in views), then semantic tokens that map to primitives per mode. Views only ever touch semantic tokens.

### 1.1 Primitives (raw — do not use in views)

| Token | Hex | Notes |
|---|---|---|
| `bone` | `#E8E6E1` | Base page, light mode |
| `bone-raised` | `#EFEDE8` | Raised card/section, light mode |
| `ink` | `#1A1A1A` | Full-contrast marks: filled dots, cursor |
| `ink-soft` | `#262320` | Written text — one step off full ink |
| `bone-soft` | `#DEDAD3` | Written text, dark mode |
| `graphite` | `#4A4843` | Muted header type |
| `stone` | `#A9A6A0` | Metadata, unfilled dots (light) |
| `hairline` | `#C9C6BF` | Rules, dividers, dots faint (light) |
| `char` | `#161514` | Base page, dark mode |
| `char-raised` | `#201F1D` | Raised card/section, dark mode |
| `bone-type` | `#E8E6E1` | Full-contrast text, dark mode |
| `graphite-dk` | `#B8B5AE` | Muted header type, dark mode |
| `stone-dk` | `#6B6862` | Metadata, unfilled dots (dark) |
| `hairline-dk` | `#332F2B` | Rules, dividers (dark) |

No accent color exists in the system by design. If one is ever added it is a deliberate, documented exception.

### 1.2 Semantic tokens (use these)

| Semantic token | Light → primitive | Dark → primitive | Role |
|---|---|---|---|
| `surface.page` | `bone` | `char` | App background |
| `surface.raised` | `bone-raised` | `char-raised` | Dot-grid card, settings sections |
| `surface.inverted` | `ink` | `bone-type` | v2 reflection cards, quote callouts |
| `text.written` | `ink-soft` | `bone-soft` | **The user's own writing (the darkest *text* on the page, one step off full ink)** |
| `text.heading` | `graphite` | `graphite-dk` | Grotesk day/screen headers |
| `text.meta` | `stone` | `stone-dk` | Mono metadata, timestamps, labels |
| `text.onInverted` | `bone-raised` | `ink` | Text inside `surface.inverted` |
| `dot.filled` | `ink` | `bone-type` | A day written |
| `dot.empty` | `hairline` | `stone-dk` | A day not written |
| `dot.today` | `ink` | `bone-type` | Today marker (see §5 for treatment) |
| `line.rule` | `hairline` | `hairline-dk` | Dividers, header underlines |
| `line.cursor` | `ink` | `bone-type` | Writing caret |

**Contrast intent:** `text.written` is the darkest text on any screen (only the dot/cursor marks sit at full ink). `text.heading` sits deliberately below it. `text.meta` is faintest. This ordering is the system's spine and must hold in both modes — verify `text.heading` never reads as dark as `text.written`.

---

## 2. Typography

Three registers, each with one job. No fourth register. No mid-weight drift — 400 and 500 only.

### 2.1 Families

| Token | Family | Fallback | Role |
|---|---|---|---|
| `font.heading` | Grotesk — *final choice pending bake-off* | system sans | Headers, structural chrome |
| `font.body` | Serif — reading/writing face | Georgia / New York | The writing surface + archive reading |
| `font.meta` | Monospace | SF Mono / system mono | Metadata, timestamps, grid labels |

**Grotesk bake-off (resolve before Stage 1):** set each against the body serif on the Today screen and pick the most editorial pairing.
- *Neue Haas Grotesk* — the classic; warm, humanist, safe.
- *Söhne* — slightly more contemporary/Swiss; excellent at header sizes.
- *ABC Diatype* — cooler, more mechanical; leans into the "Department of Time" bureaucratic register.

Recommendation to enter the test with: **Söhne** as the front-runner for header warmth without losing the grotesk crispness — but decide by eye on-device.

Body serif candidate: a high-readability text serif (not a display Didot — save high-contrast display cuts for large moments only). Something like *Newsreader*, *Source Serif*, or *Lyon Text* reads well at 16px on-device.

### 2.2 Type scale

| Token | Family | Size / Line-height | Weight | Tracking | Transform | Color token |
|---|---|---|---|---|---|---|
| `type.display` | heading | 32 / 1.1 | 500 | -0.01em | none | `text.heading` |
| `type.title` | heading | 22 / 1.2 | 500 | -0.005em | none | `text.heading` |
| `type.written` | body | 17 / 1.8 | 400 | 0 | none | `text.written` |
| `type.writtenLarge` | body | 18 / 1.75 | 400 | 0 | none | `text.written` |
| `type.reading` | body | 17 / 1.8 | 400 | 0 | none | `text.written` |
| `type.meta` | meta | 11 / 1.4 | 400 | 0.14em | UPPERCASE | `text.meta` |
| `type.metaSmall` | meta | 10 / 1.4 | 400 | 0.14em | UPPERCASE | `text.meta` |

Notes:
- `line-height: 1.8` on written/reading text is deliberate and load-bearing — it's most of what makes the surface feel like a book. Do not tighten below 1.7.
- Metadata is always uppercase, tracked `0.14em`, and never darker than `text.meta`. This is inviolable.
- Optional drop cap in the archive reading view: body serif, ~2.5× cap height, `text.written`, first line of a day. Treat as a per-day flourish, not every entry.

---

## 3. Spacing

Whitespace is a material with a budget. The scale is generous by default.

| Token | Value | Typical use |
|---|---|---|
| `space.xs` | 6px | Meta label → its content |
| `space.sm` | 10px | Timestamp → entry text |
| `space.md` | 22px | Around the day rule (above) |
| `space.lg` | 34px | **Between entries; day rule (below)** |
| `space.xl` | 44px | Screen top padding; before the dot grid |
| `space.2xl` | 48px | Major section separation (entries → grid) |

Screen horizontal padding: **28px** (`space.screenX`). Card internal padding: **20–22px** (`space.card`).

The `space.lg` (34px) inter-entry gap is the value that makes the page breathe — it came directly from the approved concept and should be treated as a floor, not a target to compress.

---

## 4. Radii & lines

| Token | Value | Use |
|---|---|---|
| `radius.card` | 14px | Raised cards (dot grid, settings) |
| `radius.control` | 8px | Buttons, inputs |
| `radius.pill` | 999px | Capture button, circular controls |
| `line.weight` | 1px | All rules and dividers — hairline only |

No shadows in the system. Elevation is expressed through the raised bone tint (`surface.raised`), never through drop shadows.

---

## 5. Dots (the signature)

The dot is the product's atom. Spec it precisely.

| Token | Value | Notes |
|---|---|---|
| `dot.size` | 7px | Default day dot (filled or empty) |
| `dot.size.today` | 11px | Today, enlarged |
| `dot.today.ring` | 1.5px, offset 2px | Outline ring around today's dot |
| `dot.gap` | 12px | Grid gap in the month card |
| `dot.grid.cols` | 7 | Month view = 7 columns (week-aligned) |

States:
- **Filled** (`dot.filled`) — a day the user wrote.
- **Empty** (`dot.empty`) — a day in range, not written. Faint.
- **Today** — enlarged (`dot.size.today`) + ring; filled if written today, otherwise ringed empty.
- **Future** — same as empty; the grid shows the whole month, future days simply unfilled.

Year/matrix view (archive): same atoms, smaller `dot.size` (4–5px) and tighter `dot.gap` (6px), rendered as a dense field. Density is the emotional payoff — do not cap the year at a single screen if scrolling shows more accumulation.

---

## 6. Motion

Tiny, consistent vocabulary. Motion should feel like dots settling, not an app animating.

| Token | Value | Use |
|---|---|---|
| `motion.fast` | 180ms | Entry save, dot fill |
| `motion.base` | 260ms | Today ↔ archive transition |
| `motion.ease` | cubic-bezier(0.22, 0.61, 0.36, 1) | Default easing (gentle ease-out) |

Three sanctioned motion moments (no others without a documented reason):
1. **Today ↔ archive** — a calm cross-fade/slide at `motion.base`.
2. **Voice capture** — a live dot that breathes/pulses while recording; on stop, transcribed text settles into place.
3. **Entry save** — the faintest acknowledgment at `motion.fast`; no toast, no checkmark. The text simply commits.

---

## 7. SwiftUI mapping (implementation hint)

```
enum Endpaper {
    enum Palette {
        static let bone      = Color(hex: 0xE8E6E1)
        static let ink       = Color(hex: 0x1A1A1A)
        static let graphite  = Color(hex: 0x4A4843)
        static let stone     = Color(hex: 0xA9A6A0)
        static let hairline  = Color(hex: 0xC9C6BF)
        // …dark-mode primitives
    }
    // Semantic tokens resolve via @Environment(\.colorScheme)
    // e.g. Endpaper.text.written → ink (light) / boneType (dark)
}
```

Prefer `Color` assets in the asset catalog with light/dark variants over runtime branching where possible — it keeps the semantic layer declarative and gives you free system-level dark mode.

---

## 8. Definition of done (Stage 0)

- [ ] Full palette entered as Figma color variables, both modes, semantic layer mapping to primitives
- [ ] Three type registers as text styles with exact size/line-height/tracking
- [ ] Spacing, radii, dot, and motion values as number/string variables
- [ ] Grotesk bake-off run on the Today screen; winner recorded here
- [ ] Body serif selected and recorded here
- [ ] A single "token proof" frame showing every token in use, both modes, side by side
- [ ] Values mirrored into a SwiftUI `Endpaper` theme file, ready for Stage 1 screens

When this checklist is complete, Stage 1 (core screens) can begin with zero primitive decisions left to make.

# Endpaper — Design System

**Version:** 2.0 · October 2, 2026 · covers the 1.0.4 build (free model)
**Supersedes:** `endpaper-design-tokens.md` (Stage 0, July 5) for everything
below; that file stays as the Figma variable sheet.
**Source of truth in code:** `ios/Endpaper/Support/Tokens.swift`,
`Type.swift`, `WrittenFormat.swift`. Views never touch a raw hex or a raw
point size — only the semantic names here.

---

## 0. Principles

1. **The page is the product.** Every screen is a sheet of bone (or char)
   with ink on it. No chrome, no bars, no badges, no shadows.
2. **Two worlds.** The page (light surface, where you write) and the
   inverted surface (where the app speaks back: reflections, offers,
   arrivals). Crossing between them is always a *moment*.
3. **Counting, never analysis.** Reflections show your own words, verbatim,
   with a number. The system never interprets, scores, or advises.
4. **Permanence has a look.** Nothing animates away. Things settle, seat,
   and stay.
5. **One accent, and it means capture.** Rose appears only where your
   voice or camera touched the page. It is never a highlight.
6. **Quiet type does the talking.** Three registers — a grotesk for
   headings, a serif for writing, a mono for metadata — and nothing else.
7. **Motion is arrival.** Everything moves on one ease-out curve, fast,
   and reads as something landing, not gliding.

---

## 1. Color

### 1.1 Primitives (never used by views)

| Name | Hex | Role |
|---|---|---|
| bone | `#E8E6E1` | page, light |
| bone-raised | `#EFEDE8` | cards, light |
| bone-soft | `#DEDAD3` | written text, dark |
| bone-type | `#E8E6E1` | full-contrast marks, dark |
| ink | `#1A1A1A` | full-contrast marks, light; inverted surface |
| ink-soft | `#262320` | written text, light |
| graphite | `#4A4843` / dk `#B8B5AE` | headings |
| stone | `#A9A6A0` / dk `#6B6862` | metadata, empty dots (dark) |
| hairline | `#C9C6BF` / dk `#332F2B` | rules, empty dots (light) |
| char | `#161514` | page, dark |
| char-raised | `#201F1D` | cards, dark |
| rose | `#C2685C` / dk `#D07A6C` | capture accent |

### 1.2 Semantic tokens (what views use)

| Token | Light | Dark | Use |
|---|---|---|---|
| `Surface.page` | bone | char | every screen |
| `Surface.raised` | bone-raised | char-raised | cards in the page's slot, settings groups |
| `Surface.inverted` | ink | bone-type | reflections, offers, arrival + glimpse sheets, toggle tint |
| `Text.written` | ink-soft | bone-soft | the user's words — the darkest *text* anywhere |
| `Text.heading` | graphite | graphite-dk | day headings, card titles |
| `Text.meta` | stone | stone-dk | mono labels, timestamps, ghost prompts |
| `Text.display` | ink | bone-type | full-contrast display moments only (onboarding opener) |
| `Text.onInverted` | bone-raised | ink | all type on the inverted surface |
| `Dot.filled` / `Dot.today` | ink | bone-type | a day written / today |
| `Dot.empty` | hairline | stone-dk | a day not written |
| `Line.rule` | hairline | hairline-dk | dividers |
| `Line.cursor` | ink | bone-type | the caret and the rule-cursor |
| `Accent.capture` | rose | rose-dk | voice waveform, "· spoken" / "· scanned" markers |

**Contrast spine:** written > heading > meta. Must hold in both modes.

**Opacity steps on the inverted surface** (the only place opacity is used
for hierarchy): kicker 0.62 · meta 0.55 · secondary action 0.55 ·
disclosure 0.4–0.55 · empty dot 0.18 · page dot 0.3. On the page, the
glimpse wash is `Text.written` at 0.16.

---

## 2. Type

### 2.1 Families

| Register | Family | Role |
|---|---|---|
| heading | Instrument Sans (Söhne is the long-term target) | headings, display, buttons |
| written | Newsreader (+ Newsreader Italic) | everything the user wrote; quotes; questions |
| meta | Fragment Mono | labels, stamps, counts, kickers — always uppercase, tracked |

### 2.2 Fixed registers

| Modifier | Size / line / weight / tracking | Color |
|---|---|---|
| `typeDisplay` | 32 / 1.1 / 500 / −0.01em | heading |
| `typeTitle` | 22 / 1.2 / 500 / −0.005em | heading |
| `typeWritten` | 17 / 1.8 / 400 | written |
| `typeWritten(large)` | 18 / 1.75 | written |
| `typeMeta` | 11 / 1.4 / 0.14em, uppercase | meta |
| `typeMetaSmall` | 10 / 1.4 / 0.14em, uppercase | meta |

Line height on the written register is load-bearing: never below 1.7.

### 2.3 The written grammar (`WrittenFormat`, rev. 2 — QA 2026-09-06)

The page sizes writing by *line*, never mixing sizes on one line:

| Tier | Size | Line height | When |
|---|---|---|---|
| large | 34 | 1.25 | a lone word (≤18 chars) on the first line of a block |
| medium | 22 | 1.5 | the first line of a block, if it fits one rendered line at 22 (measured, not guessed) |
| body | 17 | 1.8 | everything else |
| bullet | 17 italic, hanging indent 14 | 1.8 | lines starting `• ` ("- " converts as you type); pins the block to body |

A blank line starts a new block and re-arms the hero line. The same
grammar renders the live editor, committed sections, the Notebook, and
share cards, so writing rests exactly as it was written.

### 2.4 Inverted-surface sizes (reflections)

| Element | Spec |
|---|---|
| Kicker (PromptBeat prompt) | meta 11, 0.14em, onInverted 0.62; holds centered at 1.5× for 1.0 s (0.5 s in onboarding), then seats top-center |
| Opener title | heading 44 / 1.08 / 600 ("Your\nweek.") |
| Statement | heading 34 / 1.12 / 600, centered |
| Offer / ask | heading 32 / 1.15 / 600 |
| The word | Newsreader Italic 54, minScale 0.5 |
| The big line | Newsreader 46 / 500, minScale 0.4 |
| The question | Newsreader Italic 22, onInverted 0.95 |
| A verbatim quote | Newsreader Italic 19, onInverted 0.9, curly quotes, day stamp beneath |
| Counter | Fragment Mono 100, monospaced digits, counts up over 28 steps |
| Sitting | Fragment Mono 64 ("8 min") |
| Beat meta | meta 10, onInverted 0.55 |
| Glimpse number | Newsreader 96 / 500 |

---

## 3. Spacing, radii, lines

| Token | Value | Use |
|---|---|---|
| `Space.xs` | 6 | between a title and its meta |
| `Space.sm` | 10 | inside controls, between stacked meta |
| `Space.md` | 22 | beat content stacks, section gaps |
| `Space.lg` | 34 | between entries (a floor, not a target) |
| `Space.xl` | 44 | screen top, before the dot grid, before the card slot |
| `Space.xxl` | 48 | page bottom, seated kicker top |
| `Space.screenX` | 28 | horizontal page margin |
| `Space.card` | 22 | card padding |
| `Radius.card` | 14 | cards; sheets use 28 (card × 2) |
| `Radius.control` | 8 | buttons |
| `Radius.pill` | 999 | bar pills |
| `lineWeight` | 1 | every rule |

No shadows anywhere. Elevation is `Surface.raised` tint only.

---

## 4. Dots (the signature)

| Register | Dot | Gap | Where |
|---|---|---|---|
| base | 7 | 12 | month grid (7 columns) |
| today | 11, with a 1.5 ring offset 2 | — | the current day |
| year | 5 | 6 | the year matrix, calendar, constellation share card |
| week | 36 / today 44 | 18 | the tappable weekly breakdown |
| week row (deck) | 14 | 12 | the seven dots drawing themselves in the weekly opener |
| onboarding month | 14 | 12 | thirty dots filling one per 55 ms, three ringed misses |

Filled = written. Empty = a hairline ring. Dots never carry a streak,
a flame, or a colour. They fill in; they do not count.

---

## 5. Motion

| Name | Curve | Duration | Use |
|---|---|---|---|
| `Motion.fast` | cubic-bezier(0.22, 0.61, 0.36, 1) | 180 ms | the commit settle (new section arrives faint, takes ink) |
| `Motion.base` | same | 260 ms | everything else: seats, reveals, card changes |
| arrival ease | cubic-bezier(0.16, 0.84, 0.24, 1) | 350–600 ms | dots landing, the hook word seating |
| dive | cubic-bezier(0.22, 0.61, 0.36, 1) | 550 ms | the dot scaling ×280 to fill the screen (splash, daily arrival) |

Set pieces, all on the curves above:

- **Daily arrival** — countdown line (heading 34) holds 1.4 s, the dot
  dives, the page fades in. Once per day. Reduce Motion skips it.
- **The hook** — the first word of a day's first entry types at 40 pt,
  centered over a centered ghost question with the rule-cursor beneath;
  on the first space it seats top-left and scales to 34 in 0.45 s.
- **Date shrink** — the day heading drops to "Sep 5" at 0.7× five seconds
  after typing begins.
- **PromptBeat** — kicker holds centered, slides to its seat (0.4 s),
  content rises 16 pt into place 250 ms later.
- **Sequence** — each timed beat carries a 2 pt reverse countdown bar
  (opener 4 s, beats 5.5 s); tap right to advance, left third to go back,
  hold to pause. Unpaced beats (close, offer) hold for their button.
- **Counters** count up over 28 steps; **week dots** draw left to right;
  the **glimpse wash** draws left to right in 0.5 s.
- **Blinking cursor** — a 1.5 pt rule, opacity 1 → 0.08 every 0.55 s.

Every animation has a Reduce Motion branch that lands on the final state.

---

## 6. Components

### 6.1 The page (Today)
Day heading (`typeDisplay`, or "Sep 5" at 0.7× once writing starts) ·
entries meta (`typeMetaSmall`: "2 entries · 4 min") · countdown line +
the reflect mark (two 11 pt circles, one outlined, one filled, in meta) ·
a 1 pt rule · committed sections (time stamp in meta, text in the written
grammar) · the live editor · the card slot · the writing bar.

**Ghost prompt:** Newsreader Italic 22, meta color, centered in hook mode
with the rule-cursor beneath; seven charged questions for days 0–6, then
"Write." Vanishes on the first keystroke.

### 6.2 Cards (the page's slot)
`Surface.raised`, radius 14, padding 22. Title `typeTitle`, one line of
`typeMetaSmall`, then an action row: primary in meta uppercase in
`Text.written`, "Later" in meta. The whole card is the tap target. One
card rests inline; two or more become a horizontal, snapping, page-width
carousel. Every card has its own Later. Kinds: week ready, month ready,
year ready, thin week ("Not enough to reflect on yet", Okay only),
reminder pre-prompt, rating ask.

### 6.3 The writing bar
Pills: meta uppercase in a 1 pt hairline capsule (`REC`, `↑ UPLOAD`,
`DONE`). No fills, no icons beyond the ○ record mark.

### 6.4 The inverted surface
Full-screen decks (weekly, monthly, yearly), the monthly gate, and the
sheets all live on `Surface.inverted` with `Text.onInverted`. Openers
carry one geometric mark: a hollow 260 pt ring top-right for the week,
a cropped 300 pt disc for the month. A week is the outline of a month.

### 6.5 Sheets
Inverted, `presentationCornerRadius` 28, no drag indicator, fixed detent.
- **Arrival sheet** (400 / 500 locked): kicker · "Your week\nis ready." (34/600) · meta · primary button · Later.
- **Glimpse sheet** (420): the number (Newsreader 96) · "A pattern emerges" (22/500) · "You wrote “stressed” 3 times this week." (written 17 at 0.85) · Noted.
- **Membership sheet**: kicker · "Every week.\nEvery month.\nA year you can hold." (34/600) · one line · Join · Not now · Restore.

### 6.6 Buttons
- **Primary (inverted):** heading 17 / 500 in `Surface.inverted` on a `Text.onInverted` fill, padding 44 × 17.6, radius 8.
- **Secondary:** meta 11 uppercase at 0.55 ("Not now", "Later", "Continue").
- **Page actions:** written 17 for the action itself ("Join — reflections, every week"), meta beneath.
- **Links:** meta 10 uppercase, underlined, at 0.8.
- **Toggles** tint `Surface.inverted`.
- Never a destructive style. Nothing in Endpaper deletes.

### 6.7 Subscription disclosure (`MembershipTerms`)
On every purchase surface: product name · 1 year · live price · intro
offer (only if StoreKit reports one) · auto-renew line · Privacy Policy
and Terms of Use links. Meta 9–10, centered.

### 6.8 The glimpse wash
`Text.written` at 0.16, radius 3, tight to the glyph line (+3 / +1 pt),
behind the last occurrence of the word, in the live editor or the
committed section. Draws in left to right. Tap target is the word ±12 pt.

### 6.9 Share cards
360 × 450 at 3×. **Line card** (bone): drop cap, the line in the written
grammar, "Written on {date}", `ENDPAPER.SPACE` in meta. **Constellation
card** (char): the month's dots at the year register, month name beneath.

### 6.10 Notebook
Month heading (`typeTitle`), day heading, rule, then the day's text in the
written grammar with a drop cap only on a body-size opening line.
Reflections rest as inverted rows ("REFLECTION · SEP 4 – 11") at the
period's last day; tap reopens the archived deck, never recomputed.

---

## 7. Voice

- Quiet, direct, complete sentences. First person when the maker speaks.
  No exclamation points. No feature-matrix language.
- Reflections speak in kickers and counts: "Kept surfacing" · "You wrote
  this large" · "You asked yourself" · "Your longest sitting". Never
  "insight", never "analysis", never advice.
- Dates: "Saturday, July 5" on the page, "Sep 4 – 11" for weeks,
  "September 2026" for months. Times "2:09 PM". Stamps in meta.
- The membership is a membership, not a plan or a tier. Writing is free,
  forever. Reflections are "every week, every month, a year you can hold."
- Privacy: "we count taps, never words."
- Permanence is stated as a fact, not a warning: "Sealed at midnight."

---

## 8. Marketing grammar (the kits)

The quote-motion Reel is the page itself at 1080 × 1920: the day heading
in the grotesk, a 2 pt rule, the first letter typed huge (the hook frame
every kit is verified on), shrinking into the written grammar, the
emphasised word pressed, a meta stamp, `ENDPAPER.SPACE` at the foot.
Light variants carry a morning stamp and post for the US morning; dark
variants carry an evening stamp and post for the US evening. Captions are
the stamp line ("Thought of Monday, Sep 28th at 7:22am", or "Asked myself
on…" for questions, "From {Name} - " only when the attribution is
verified). First comment, always: "I wrote this in the Endpaper app".

App Store lockups and rule cards use the same three registers on bone or
char, one statement per canvas, the dot punctuating, the product shown as
an element in a composition rather than a rectangle with a headline.

---

## 9. Rules that have survived QA (do not relitigate)

- Never two text sizes on one line.
- Nothing auto-presents; a deck opens on a tap. The arrival sheet
  announces, once.
- The consent card is gone; reflections are on by default.
- The reflection week is anchored on the first day, not the calendar.
- No page dots on decks; the countdown bar and tap-left-to-go-back.
- The ghost prompt is centered; the cursor sits beneath it, never beside.
- Demo tools never ship visible: sandbox + seven taps on "Settings".
- No fake attributions, anywhere, ever.

# Vellum

*The journal that is just a journal.*

A journaling app reduced to its essence: open it, write or speak, close it.
No folders, no tags, no prompts. The product is a quiet, beautiful log of your
thinking over time — see [`docs/journal-pdp.md`](docs/journal-pdp.md).

## This repo, right now

A **high-fidelity web prototype** of the V1 core loop. It is the living design
spec: every color, size, spacing, and motion value resolves to the Stage 0
token sheet ([`docs/vellum-design-tokens.md`](docs/vellum-design-tokens.md)),
mirrored 1:1 in [`styles/tokens.css`](styles/tokens.css).

The **native SwiftUI port** (iOS 17+, SwiftData + CloudKit) now lives in
[`ios/`](ios/README.md) — round 1 covers the token sheet, type registers,
data layer, Today, the archive, onboarding, the reminder, and the StoreKit 2
trial gate. Generate the Xcode project with `xcodegen` (see `ios/README.md`).

### What works

- **Onboarding** — the four-screen tutorial (Attention is a practice /
  This is Vellum with the dot-fill moment and the permanence rule /
  Reflect, if you wish — the reflections preview / Go forth) with dots as the
  page indicator, then the account moment ("Keep your notebook." —
  Back up with iCloud per Path A, "Continue without an account" as a
  first-class skip), then the trial moment ("A week on me." — 7-day
  trial, hard paywall, no freemium). Shows once; replay via the footer's
  Intro.
- **Reminder pre-prompt** — the in-system card that precedes any
  permission dialog, offered after two written days; a no is never
  re-asked.
- **Today** — the blank page as home screen: date heading, mono meta row,
  cursor ready on load. Entries auto-commit (idle / blur / ⌘↩) with the
  180 ms settle; a faint `SAVED 9:41 AM` is the only acknowledgment.
- **Voice capture** *(v1.1 fast follow — designed here, ships post-launch)* —
  the breathing-dot recorder, transcribing into the writing surface via the
  Web Speech API where the browser supports it.
- **Archive → Notebook** — reverse-chronological reading view, two-line
  drop cap per day.
- **Archive → Calendar** — one morphing experience: year matrices → tap a
  month row → all twelve month cards (anchored to the tapped month) → tap a
  month → its weekly breakdown (one expanded at a time) → tap a large dot →
  that day's page. Dots physically travel between layouts (FLIP).
- **Archive → Find** — full-screen overlay, bar centered until you type;
  the query starts huge and shrinks to fit, results grouped by day with
  matches underlined.
- **Yearly wrapped (R3)** — from the Calendar year view ("Your year →",
  consent required): the year matrix draws itself dot by dot, the big
  numbers, the top five threads, the most-discussed reveal with its
  first-ever mention, and "See you on the page." with a save-as-image of
  the dots (dots and counts only — the writing never leaves).
- **Reflections (R1+R2)** — consent card on Today (appears only once a
  recap could exist); weekly reflection and monthly recap arrive as the
  reserved inverted-card modal (one arrival per visit, monthly first);
  condensed on-color cards rest at period boundaries in the Notebook and
  reopen the full card on tap. Content comes from a deterministic
  quote-first engine (no AI yet): topics need repeated mentions, every
  quote is verbatim, tone words must be the user's own, difficulty needs
  explicit textual evidence, thin weeks stay silent and thin months get
  the honest quiet variant. See
  [`docs/vellum-reflection-spec.md`](docs/vellum-reflection-spec.md).
- **Dark mode** — token-level, follows the system, footer override.
- Entries persist in `localStorage` (day-keyed plain text — the v2-ready
  corpus shape).

### Run it

Fastest: double-click **`preview.html`** — a self-contained build (fonts and
all) that runs straight from the file, no server. Its footer has a
`Seed demo / Clear` control for demo data and the theme toggle. Rebuild it
after source changes with `node tools/build-preview.js`.

Full version (real `localStorage` persistence), no dependencies:

```sh
python3 -m http.server 4173
# → http://localhost:4173          (empty, first-run state)
# → http://localhost:4173/?seed    (fills ~16 months of demo entries)
```

### Structure

```
docs/       PDP + Stage 0 design tokens (source of truth)
styles/     tokens.css (the token sheet) · app.css (components)
js/         store, views (today / archive / year), dots, voice, seed
fonts/      self-hosted OFL fonts — Newsreader (body serif),
            Instrument Sans (grotesk stand-in for Söhne), Fragment Mono (meta)
ios/        the SwiftUI port (XcodeGen project — see ios/README.md)
```

### Governing constraints

- The user's writing is the only full-contrast element on any screen.
- Views never touch raw hex or raw sizes — semantic tokens only.
- No shadows; elevation is the raised-bone tint. No icons where a word or a
  dot will do. No accent color, by design.

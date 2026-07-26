# Endpaper — iOS (SwiftUI port)

The native build the web prototype was always specifying: SwiftUI,
iOS 17+, SwiftData + CloudKit (Path A — the user's own iCloud is the
account; no server, no login). Every color, size, spacing, and motion value
resolves to `Endpaper/Support/Tokens.swift`, a 1:1 port of
`../styles/tokens.css`, which itself mirrors
[`../docs/endpaper-design-tokens.md`](../docs/endpaper-design-tokens.md).

## Build

The Xcode project is generated, never committed:

```sh
brew install xcodegen
cd ios
xcodegen          # → Endpaper.xcodeproj
open Endpaper.xcodeproj
```

Then in Xcode: set your development team (Signing & Capabilities), and to
exercise the real trial/purchase flow, set the scheme's StoreKit
configuration to `Endpaper.storekit`. Without it the trial gate falls back to
a locally stamped 7-day window (the same mock the web prototype uses).

CloudKit ("Back up with iCloud") needs the iCloud capability active on your
team's app ID — the entitlements file already names
`iCloud.com.wendellbarton.endpaper`. "Continue without an account" runs the
store local-only; no capability required.

## What's here (port round 1)

- **Design tokens & type registers** — the full token sheet; the three
  registers (Instrument Sans display, Newsreader 17/1.8 writing, Fragment
  Mono 11/0.14em meta) using the same OFL variable fonts, bundled as TTFs.
- **Data layer** — `Entry` (SwiftData, CloudKit-ready), append-only
  `EntryStore` with the 30-minute session merge. No edit or delete API, by
  design: what you write stays written.
- **Today** — heading, mono meta row, committed sections, the writing
  surface with cursor ready; auto-commit on 5 s idle / backgrounding /
  navigating away; the faint `SAVED 9:41 AM` acknowledgment; drafts survive
  relaunch and a stale draft commits to its own day.
- **Archive** — Notebook (reverse-chronological, two-line drop caps),
  Calendar (year matrices → month grid → weekly breakdown in the 36/44
  register → the day's page, with `matchedGeometryEffect` standing in for
  the web's FLIP), Find (centered-until-typed, shrinking query, matches
  underlined).
- **Onboarding** — the four tutorial slides (dot-fill moment, permanence
  rule, reflections preview), the account moment ("Keep your notebook.",
  Path A), and the trial moment ("A week, on me." — 7-day trial, hard
  paywall, no freemium).
- **Reminder** — the pre-prompt card after two written days; the system
  dialog only ever follows a yes; one-shot re-armed notifications that skip
  days already written; the four-line copy pool.
- **Trial gate** — StoreKit 2 (`TrialGate`), yearly product with a 7-day
  free introductory offer, `Endpaper.storekit` test configuration.

## Round 2: the reflection layer (ported)

- `Reflect/Reflect.swift` — the deterministic engine, a line-faithful port
  of `../js/reflect.js`: same thresholds, stopwords, tone vocabulary,
  difficulty markers, and quote-dedupe passes. (One deliberate deviation:
  Swift's sort isn't stable, so rankings carry explicit alphabetical
  tiebreaks — both engines are deterministic; ties may order differently.)
- `Reflect/ReflectionStore.swift` — consent/seen/archived state under the
  same `endpaper.reflection.v1` key; pending-arrival logic (one per visit,
  monthly wins); the SwiftData → corpus bridge.
- `Reflect/SlideSequence.swift` — the timed-slide machinery: reverse
  countdown bar, tap to skip, touch-and-hold (250 ms) to pause,
  fit-to-width decorative intertitles.
- `Reflect/RecapView.swift` + `WrappedView.swift` — the monthly and yearly
  sequences (month grid drawing itself, topics/tone/challenges, the year
  matrix, five threads, the reveal, save-your-year share image — dots and
  counts only).
- `Reflect/ReflectionViews.swift` — consent card on Today, the weekly
  inverted card, condensed archived cards resting at period boundaries in
  the Notebook (tap to reopen).

## Not yet ported (next rounds)

- Settings (reminder time, backup toggle, replay intro, export).
- The trial-expiry paywall screen (gate exists in `TrialGate`).
- Voice capture (v1.1 fast follow, per the PDP).
- Face ID lock.

## Governing constraints (unchanged)

- The user's writing is the only full-contrast element on any screen.
- Views never touch raw hex or raw sizes — semantic tokens only.
- No shadows; elevation is the raised-bone tint. No icons where a word or a
  dot will do. No accent color, by design.

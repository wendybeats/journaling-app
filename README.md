# Vellum

*The journal that is just a journal.*

A journaling app reduced to its essence: open it, write or speak, close it.
No folders, no tags, no prompts. The product is a quiet, beautiful log of your
thinking over time — see [`docs/journal-pdp.md`](docs/journal-pdp.md).

## This repo, right now

A **high-fidelity web prototype** of the V1 core loop. It is the living design
spec: every color, size, spacing, and motion value resolves to the Stage 0
token sheet ([`docs/vellum-design-tokens.md`](docs/vellum-design-tokens.md)),
mirrored 1:1 in [`styles/tokens.css`](styles/tokens.css). The eventual native
build is SwiftUI (iOS 17+, SwiftData + CloudKit) and ports these tokens directly.

### What works

- **Today** — the blank page as home screen: date heading, mono meta row,
  cursor ready on load. Entries auto-commit (idle / blur / ⌘↩) with the
  180 ms settle; a faint `SAVED 9:41 AM` is the only acknowledgment.
- **Voice capture** — the breathing-dot recorder, transcribing into the writing
  surface via the Web Speech API where the browser supports it (stands in for
  the on-device Speech framework).
- **Month dot grid** — 7-column week-aligned card; filled = written,
  today enlarged + ringed.
- **Archive → Days** — reverse-chronological reading view, drop cap per day.
- **Archive → Years** — the dense year matrix; every year with data renders.
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
```

### Governing constraints

- The user's writing is the only full-contrast element on any screen.
- Views never touch raw hex or raw sizes — semantic tokens only.
- No shadows; elevation is the raised-bone tint. No icons where a word or a
  dot will do. No accent color, by design.

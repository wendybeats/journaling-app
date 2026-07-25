# Engine parity harness

The launch-plan checklist requires that the Swift reflection engine
(`ios/Endpaper/Reflect/Reflect.swift`) agrees with the JS reference
engine (`js/reflect.js`) over a shared corpus. This directory is that
harness.

## Pieces

- `gen-corpus.mjs` — writes `corpus.json`: a deterministic year of demo
  writing (seeded RNG, recurring topics, skipped days), anchored to a
  **fixed date** (2026-07-24) so the fixture never drifts with the clock.
- `run-js.mjs` — runs the JS engine over the corpus and writes
  `expected.json`: four weekly signals, thirteen monthly signals, two
  yearly signals, field by field.
- `ios/Tests/ParityTests.swift` — loads both fixtures from the test
  bundle, runs the Swift engine, asserts every field matches.

## Running

JS side (this repo, needs only node):

```sh
node tools/parity/gen-corpus.mjs   # only when changing the corpus shape
node tools/parity/run-js.mjs      # regenerates expected.json
```

Swift side (Mac): `cd ios && xcodegen`, open the project, **⌘U** — the
`EndpaperTests` target bundles both JSON fixtures as resources.

## Rules

- `corpus.json` and `expected.json` are committed. Regenerate `expected`
  only after an *intentional* engine change, and regenerate it from the
  JS engine — JS is the reference; Swift conforms.
- Known tolerated divergence: ranking ties. JS uses stable sort +
  insertion order; Swift uses explicit alphabetical tiebreaks. A failure
  that is a pure tie artifact (same days/mentions, different pick) gets
  recorded and the comparator aligned — a failure that isn't goes fixed
  in `Reflect.swift`.

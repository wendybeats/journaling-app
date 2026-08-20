# Recaps, comprehensive — weekly / monthly / yearly plan

> **STATUS 2026-08-20: weekly + monthly BUILT** (folded into 1.0.2,
> build 10, pre-user-testing). Weekly = five-beat swipeable deck (shape /
> thread / written-large / question / sitting → stats+Continue), each on
> the PromptBeat choreography. Monthly sequence re-paced: dot opener →
> grid → three fast numbers → opened/closed split → the turn (supersedes
> Your Word when present) → recurring ideas → people → rhythm bars →
> spoken (rose) → challenges → outro. Engine fields are optional Codable
> (old archives decode; silence rule per beat); time-shaped signals come
> from a sessions side-table on Corpus and stay out of the JS parity
> surface. Yearly sequence still parked for the December release.

*2026-08-18 · brainstorm with Wendell: "make the recaps more
comprehensive… weekly 3–5 data points, monthly a bigger recap, yearly a
full, introspective picture. Hesitant to use AI, but it needs to feel
really insightful — the user really learns something about themselves."*

## The principle: no AI, and that's the moat

The reflection engine already has the right constitution: it only
surfaces what the entries literally contain — verbatim sentences, the
user's own recurring words, explicit evidence, silence when there's
nothing honest to show. Every idea below keeps that rule.

The "insight" feeling doesn't need generation. It comes from three
deterministic moves:

1. **Selection** — their own words, chosen well.
2. **Juxtaposition** — two of their sentences placed side by side.
3. **Time** — things written too far apart for them to ever see together.

A person lives one day at a time; the recap is the only place they see
across days. That's the whole magic, and it's all retrieval.

Raw material already in the corpus: text, `at`/`lastAt` (session
timing), day keys, WrittenScale sizes (what they wrote big), and — new
in 1.0.2 — `origin` (spoken / scanned / imported).

---

## Weekly — 3–5 quiet data points (a card, not a ceremony)

1. **The shape of the week** — the 7 dots plus *when*: "evening writer —
   4 of 5 nights after 9pm." (bucket `at` by hour: morning / afternoon /
   evening / late)
2. **The thread** — exists today (one topic + verbatim quotes). Keep.
3. **What you wrote large** — the biggest WrittenScale line of the week,
   shown at its written size. The user already marked it as important by
   writing it big; the recap just remembers.
4. **The question you asked yourself** — sentences ending in "?" are
   self-inquiry, quoted verbatim with their date. Zero inference,
   maximum introspection. Silent if none.
5. **Longest sitting** — "22 minutes, Tuesday night" (`lastAt - at`).

## Monthly — the current sequence plus a narrative arc

Keep: circles intro, grid drawing, big numbers, recurring ideas, Your
Word, Challenges. Add:

- **The month opened / the month closed** — first sentence of the first
  entry and last sentence of the last, side by side. A story arc for
  free.
- **The turn** — tone trajectory by half-month: "'tired' faded after
  the 14th; 'steady' took its place." (run the existing tone counter on
  each half; show only when the leader changes)
- **Where it started / where it landed** — the top topic's earliest and
  latest quotes juxtaposed.
- **People** — recurring capitalized mid-sentence words (≥3 days):
  "Anna — 9 days this month." Deterministic proper-noun heuristic;
  silent when nothing recurs.
- **Your rhythm** — weekday histogram in mono bars, your most common
  writing hour, capture mix ("6 sections spoken aloud" — `origin`).
- **This time last year** — once the corpus is ≥13 months old, one
  verbatim line from the same month last year. The recap gets better
  every year they stay.

## Yearly — the full portrait

Keep: the matrix drawing itself, the numbers, five threads, the
most-discussed reveal with its first mention, share card. Add:

- **The year in twelve lines** — the centerpiece. One verbatim sentence
  per month (the month's top-topic sentence, else its biggest-written
  line), stacked chronologically. A found poem of their year, written
  entirely by them. Share-safe *only by explicit choice* — the default
  share stays dots-and-counts.
- **The comeback** — the longest gap between written days, and the
  verbatim line written on the day they returned.
- **What you put down** — a thread alive in H1, absent in H2: "you
  stopped writing about the job in June."
- **The constant** — the one word that appeared in the most months.
- **Seasons** — topic-per-quarter timeline; tone word by quarter.
- **Texture numbers** — "your 100,000th word landed on Oct 3."
- **People of the year** — same heuristic as monthly, yearly bar.

---

## Engineering notes

- All of this extends `Reflect.swift`'s existing patterns: tokenize /
  sentences / counts with explicit thresholds and alphabetical
  tiebreaks. Every new section obeys the silence rule — no evidence, no
  slide, never a reach.
- New fields on the Codable signals must be **optional** so archived
  reflections (persisted whole) still decode.
- JS reference engine (`js/reflect.js`) should gain the same signals to
  keep the parity suite honest, or the new fields stay Swift-only and
  out of the parity corpus — decide per signal.
- Proper-noun heuristic: capitalized token not at sentence start, not
  month/day names, ≥4 letters, appearing on ≥3 distinct days. Show at
  most 2; silence otherwise.

## Card design direction (Wendell's Figma pass, 2026-08-18)

Ingested from his store-shot Figma round — applies to ALL dynamic
layouts (recap cards, sequences, share cards) going forward, not just
this feature:

- **Less on every screen.** His screens carry one statement + one visual
  against our tendency to stack; the old three-stat slide becomes three
  fast one-number beats.
- **One focal element per screen.** Everything else is a whisper around
  it.
- **Three registers do the hierarchy.** Mono (small, tracked) frames;
  Newsreader italic speaks the user's words; Instrument Sans semibold
  states findings. The size gap between registers is the design.
- **Vary the layout beat to beat** so the eye stays interested: type-only
  → graphic → number → split → ghost/ink. No two adjacent screens share
  a shape.
- **The dot punctuates.** Huge, cropped off-edge, exactly once per
  sequence — an exclamation, not wallpaper.
- **Ghost → ink** renders time: outlined type is "before," solid is
  "now" (the monthly "turn" slide).
- **Splits juxtapose without commentary** — two moments stacked across a
  hairline; the reader draws the conclusion.
- **The prompt choreography** (Wendell, 2026-08-18): each beat opens with
  its prompt ("You asked yourself") centered, ~1.5× size, full ink. Hold
  ~1s, slide up ~400ms (ease-out, the house curve 0.22/0.61/0.36/1) into
  its small seat at the top, settling to the muted-but-contrasted meta
  color (~62% ink — brighter than the old stone). Only then does the
  metric rise in. Question before answer, every time. Reduce Motion:
  prompt sits at rest, metric appears without travel.

Card studies artifact (approved direction pending Wendell's review):
weekly = five-beat swipeable mini deck in the Today feed (shape /
thread / written-large / question / sitting); monthly sequence pacing =
dot opener → grid → fast numbers → opened-closed split → ghost-ink turn
→ name → mono bars → spoken (the rose's one recap appearance) → outro.

## Sequencing

1. **1.0.2/1.0.3** — weekly upgrade (shape, big line, question, sitting)
   + monthly *opened/closed* and *the turn*. Small, high-feel.
2. **Next** — monthly people, rhythm, where-it-started/landed.
3. **December release** — the yearly package (twelve lines, comeback,
   put-down, constant, seasons), timed to Wrapped season as a marketing
   moment.

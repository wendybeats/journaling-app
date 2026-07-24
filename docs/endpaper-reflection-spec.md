# Endpaper — Reflection Layer Spec (V2)

**Version:** 1.0
**Date:** July 7, 2026
**Owner:** Wendell Barton
**Status:** Decisions locked July 7; design-mocked prototype is the next build step.

---

## 1. Decisions (locked)

| Question | Decision |
|---|---|
| Where AI runs | **Hybrid** — deterministic stats + on-device signals by default; narrative recaps via opt-in cloud (Claude API) behind one explicit consent moment |
| Persistence | **Modal, then archived** — arrives as a moment, then lives as an inverted card at its period boundary in the Notebook |
| Voice | **Quote-first mirror** — every claim anchored to the user's own words; no quote, no claim |
| Next step | **Design the three recap surfaces in the web prototype with hand-written mock content** over seed data; AI plumbing after the surfaces earn their shape |

## 2. Principles

1. **The mirror rule.** The AI reads writing back; it never writes for the user, never advises, never diagnoses. "You wrote about X" — never "you should," never "you seem depressed."
2. **No quote, no claim.** Every inference must cite the user's own phrase(s), verbatim, with day attribution. This is structural honesty: it makes big leaps impossible to phrase.
3. **"Not enough here" is a first-class output.** Sparse weeks, scattered topics, no correlations — the recap says so plainly and stays short. A thin recap that's true beats a rich one that's reaching.
4. **Super-obvious inferences only.** The bar: the user should nod "well, yes, obviously" — the value is seeing it *collected*, not being told something clever. Recurrence (≥3 mentions) is the only license to call something a theme.
5. **Reflections are guests in the notebook.** Inverted cards (`surface.inverted` — the reserved treatment from PDP §5.3), clearly not the user's writing, excluded from Find results and word counts. The record of *your* writing stays yours.
6. **Off by default, one consent, revocable.** The reflection layer does not exist until the user turns it on. Deleting a reflection deletes it everywhere. Turning the layer off deletes all cloud-processing consent going forward.

## 3. The three cadences

### 3.1 Weekly — *the reflection*
- **When:** Sunday evening (default 6:00 PM local, adjustable), covering Mon–Sun. Appears as a modal on next app open after that time — never a push notification.
- **Content:** ONE thing. The single most recurrent thread of the week, quote-anchored, ≤120 words, closing with a soft mirror question at most ("Worth sitting with?" — no advice).
- **Threshold:** ≥3 days written *and* ≥300 total words in the window; below that, no modal at all (silence, not an apology — absence keeps the moment scarce).
- **Anatomy** (inverted card): mono meta header `WEEK OF JUNE 29 · 4 DAYS · 1,240 WORDS` → serif body with the observation → the anchoring quotes set as pull-quotes with day stamps (`"…" — TUESDAY`).
- After dismissal: archived as an inverted card at that week's boundary in the Notebook scroll.

### 3.2 Monthly — *the recap*
- **When:** end of month; arrives on next open as a **full-screen five-slide
  sequence** (not the inverted card): 1) circles + "Reflections – Your month"
  with a 3s reverse countdown and a faint "Not interested"; 2) the month grid
  drawing itself dot by dot, then month title / days written / words /
  longest run animating in (5s bar); 3) recurring topics one at a time, word
  + day count + two verbatim quotes (3s each); 4) tone centered large, with
  "what seemed difficult" quotes entering below (3s); 5) "MONTH → NEXT" over
  "Reflect & start anew", Continue to home. Slides with nothing honest to
  show remove themselves.
- **Content, in order:**
  1. Recurring topics (2–4, each quote-anchored, each with mention counts — `THE BOAT · 6 DAYS`)
  2. Overall tone — described in the user's own vocabulary ("your word was 'tired'; it appeared nine times"), never clinical labels
  3. "What seemed difficult" — only if the writing *says* difficulty ("fighting me", "bad sleep, short fuse"); quoted, never inferred from tone alone
  4. Deterministic footer: days written, words, longest run of consecutive days
- **Threshold:** ≥8 days written; otherwise the recap is just the deterministic footer plus one honest line: "A quieter month on the page. The dots know the rest."

### 3.3 Yearly — *the wrapped*
- **When:** early January (and a mid-year teaser is explicitly out of scope — scarcity is the point).
- **Content — a paged, full-screen sequence in the dot language** (the one place Endpaper is allowed a little theater, still monochrome, still typographic):
  1. The year matrix, drawn dot by dot (the emotional opener — their actual year)
  2. Days written / total words / longest run (deterministic, mono, huge)
  3. Top 5 topics (LLM-extracted, quote-anchored, mention counts)
  4. **The reveal: your most discussed thing** — one spread, display type, with its first-ever mention quoted ("It started on March 4: '…'")
  5. Closing card: "See you on the page." + share-as-image of the dot matrix only (dots, counts — never text content; the writing never leaves)
- **Threshold:** ≥30 days written; below that, wrapped is the matrix + counts only, no topic section, one honest line.

## 4. The consent moment

- Surfaced the first time a recap *could* exist (first Sunday meeting the weekly threshold) — an in-system card, not a system dialog:
  - Title: "A weekly reflection?"
  - Body (serif): "Endpaper can read your week back to you — your own words, collected. The writing is sent once, privately, to generate it, then discarded. Nothing is stored anywhere but here."
  - Actions: `YES, REFLECT` · `NO THANKS` (both mono; no-shame decline, re-visitable in Settings)
- Cloud contract to state in-app and honor technically: TLS, no training, no retention (API zero-retention config), payload is entry text + day keys only — no name, no email, no device IDs.
- On-device/deterministic features (counts, matrix, streaks) work regardless of consent.

## 5. Honesty engineering (how "no big leaps" becomes code)

1. **Two-stage pipeline.** Stage 1 (deterministic, on device): candidate signals — token/phrase frequency across days, per-day word counts, recurring proper nouns/bigrams (≥3 distinct days). Stage 2 (LLM): *given these candidates and the raw entries*, select and phrase — the model may only claim what a candidate already supports, and every claim must return the supporting entry IDs.
2. **Structured output, validated.** The model returns JSON: `{claims: [{text, quoteSpans: [{entryId, start, end}], days}], tone?, difficulty?, insufficient: bool}`. The app **verifies every quoteSpan against the actual entry text**; a claim whose quote doesn't match verbatim is dropped client-side. Hallucination becomes a validation error, not a user-visible lie.
3. **The model is told it can pass.** The prompt makes `insufficient: true` and empty sections first-class, with examples. Phrase bank for honesty: "Not enough here to say," "No thread this week — five separate days, five separate places."
4. **Tone words must be the user's.** The tone section may only use adjectives that literally appear in the corpus window (stage-1 extracts the candidate list). If none recur, no tone section.
5. **Difficulty needs explicit textual evidence** (the user naming struggle), never sentiment inference alone.
6. **Regeneration is not a slot machine.** One recap per period; a "reload" invites fishing for flattery. If validation drops everything, the period gets the honest fallback, not a retry loop.

## 6. Surfaces & motion

- **Modal:** full-screen inverted card over a dimmed page, `motion.base` rise; dismiss = swipe down or ×. One per arrival; never queued (if two are pending, monthly wins, weekly folds into it).
- **Archived form:** the same card, resting inline at its period boundary in the Notebook (between the last day of the period and the first day of the next). Long-press → "Remove this reflection" (permanent).
- **Wrapped:** its own paged overlay, launched from a single quiet mono line on Today during January ("YOUR YEAR IS READY →"), replayable from the Calendar year view.
- Excluded from Find, excluded from entry counts, never a dot — dots are for writing.

## 7. Monetization note

✅ Decided (July 8): the whole app is a paid subscription — 7-day free
trial, hard paywall, no freemium. Reflections are included in the one
subscription (no separate AI tier); the trial moment lives at the end of
onboarding. Price points are placeholders until submission.

## 8. Build plan

| Phase | What | Where |
|---|---|---|
| R1 | Weekly modal + archived card + consent card, hand-mocked content over seed data | Web prototype (next session) |
| R2 | Monthly recap + thresholds/fallback states, mocked | Web prototype |
| R3 | Yearly wrapped paged sequence, mocked (matrix animation is the star) | Web prototype |
| R4 | Stage-1 deterministic signal extraction (real, runs on seed corpus) | Web prototype JS → ports to Swift |
| R5 | Claude API integration behind dev flag; structured output + quote validation; judge real output vs mocks. **Post-launch (decided July 24): V1 ships the deterministic engine on device only — no backend exists until R5.** | Web prototype |
| R6 | SwiftUI port alongside the rest of the app | iOS |

Mock content rule for R1–R3: write the mocks *from the actual seed entries*, obeying every rule in §5 by hand — the mocks are the spec for the model.

## 9. Open items

| # | Item | Default until decided |
|---|---|---|
| 1 | Weekly arrival time | Sunday 6 PM local |
| 2 | Claude model + zero-retention config; cost ceiling per user/month | Sonnet-class, batched |
| 3 | Does consent cover weekly+monthly+yearly in one yes, or per-cadence? | One yes covers all three (stated plainly) |
| 4 | Wrapped share-image design | Dots + counts only, no text |

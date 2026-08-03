# Endpaper — Content Engine Plan

**Date:** July 31, 2026 · The automated system for producing marketing +
UGC ourselves. Companion to docs/endpaper-marketing-brief.md (the
positioning source of truth).

**The core insight:** the web prototype renders the product
pixel-identically, and Claude's environment runs a real browser
(Playwright + Chromium). So the product's most shareable moments — the
dot matrix, the calendar choreography, the year review — can be
*generated* as finished assets, on demand, at any aspect ratio, without
Wendell touching a screen recorder. The machine produces ready-to-post
packs; Wendell's job shrinks to filming the occasional face/voice piece
and pressing Post.

---

## Layer 1 — what the machine makes (fully automated)

### 1a. Product-render assets
Playwright drives the seeded prototype (deterministic demo corpus — the
same year of writing every run) and captures:

- **Stills**: year dot matrix (well-seeded), month grids, notebook pages
  with drop caps, day pages, year-review slides — at 9:16 (Stories/
  TikTok), 1:1 (feed), 16:9 (YouTube/site), and device-frame variants.
- **Video**: the calendar choreography (year→month→day and back), the
  commit settle, the year-review sequence — Playwright records video
  natively; output trimmed to loop-ready clips.
- Light and dark variants of everything, from the same run.

### 1b. Brand cards
HTML templates in the token system (the marketing brief page proved the
pipeline) → rendered to PNG:

- **Rule cards** — one sentence of product truth set huge ("What you
  write can't be deleted. That's the point.")
- **Stat/dot cards** — month-end matrices with a quiet mono caption
- **Quote cards** — lines from the store copy / site in the voice
- These double as prototypes for the future in-app share-card feature
  (Round D) — the templates get reused, not thrown away.

### 1c. Copy
For every asset, channel-fit words in the register:
- Captions per channel (hook line + body + tags where native)
- Scripts for Wendell's face/voice pieces (15–45s, shot-by-shot)
- Maker-log posts (build-in-public thread material from actual commits —
  the git history is a content mine: the flash bug saga, the permanence
  rule, the no-analytics architecture)

### 1d. The weekly pack
A Routine (scheduled trigger) runs Monday mornings: generates the batch,
assembles `content/packs/YYYY-WW/` — assets + `captions.md` + a
one-page "this week" note — and delivers it to Wendell's phone. Review,
tweak, post. Target: ≤45 min of Wendell-time per week.

## Layer 2 — what only Wendell can do

- **Real-device captures**: thumb-on-glass recordings of the TestFlight
  build (the choreography with real momentum, the REC pill, Face ID).
  One 20-minute capture session per build feeds weeks of cuts.
- **Face/voice UGC**: the maker-story pieces ("I built a journal that
  can't delete") — scripts supplied by Layer 1, filmed in one batch.
- **Posting + replies**: no APIs will be added for auto-posting (and
  platforms punish it anyway). The machine packs; Wendell posts.
- **Community**: Reddit (r/Journaling, r/digitalminimalism, r/privacy)
  takes genuine participation, not drops — Wendell's voice only, with
  the machine drafting when asked.

## Layer 3 — formats × cadence × channels

| Format | Cadence | Channel | Angle |
|---|---|---|---|
| Maker log | weekly | X / Threads | build-in-public; starts NOW, pre-launch — launch with receipts |
| Rule cards | 2×/week | IG / Threads | permanence, no-AI, no-analytics — one truth at a time |
| Choreography clips | weekly | TikTok / Reels / Shorts | "nothing else in the category moves like this" |
| Month-end dots | monthly | all | "July, honest version" — the repeatable identity format |
| Permanence challenge | at launch | TikTok / Reels | "30 days, one honest sentence, no delete key" |
| No-AI counter-programming | opportunistic | TikTok / X | stitch/duet AI-journal content |
| Year-review season | January | all | the product's natural Wrapped moment |
| Blog / journal | biweekly | endpaper.space | SEO + the long privacy/permanence essays; feeds a launch newsletter |

## Measurement (within the no-analytics constraint)

- Per-channel UTM links → site-side (Netlify analytics only; nothing in
  the app, ever)
- App Store Connect referral sources + per-channel promo codes at launch
- The weekly pack includes last week's numbers pasted from ASC/Netlify →
  a running scoreboard doc; formats that don't move in 4 weeks get cut

## Phases

**Phase 0 — now (beta):** build the render pipeline + card templates;
start the maker log immediately; content goal is TestFlight recruits and
a waitlist on the site. Everything made now is launch inventory.

**Phase 1 — launch:** Product Hunt + press kit (assets already exist by
then); permanence-challenge push; promo codes to beta testers as the
first advocate wave.

**Phase 2 — flywheel:** ship the in-app share card (Round D) so users
generate the month-end dot format themselves; January year-review season
is the first big organic moment.

## Addendum (Aug 2, from the AI-UGC playbook review)

Reviewed the 2026 mobile AI-UGC playbook (videoai.me's own content —
discount the tool pitch, keep the mechanics). Adopted:

1. **Weekly kill/scale cycle** — losers die Friday, winners spawn
   same-family variants; replaces the softer 4-week format cut.
2. **Hook library** — `content/hooks.md`, 50–100 hooks tagged by
   audience/theme/performance, mined from App Store reviews, Reddit
   (r/Journaling, r/digitalminimalism), TikTok comments, and TestFlight
   feedback. The engine writes captions from the library, not from
   scratch.
3. **Craft rules**: hook lands ≤1.5 s; captions burned in (muted
   feeds); app identity visible at second 0 and at CTA.
4. **One variable per variant set** — hooks × one visual, or one hook ×
   visuals; never both.
5. **Paid lane at launch** — Spark/Meta on proven organic winners,
   $20–50/day tests, variant IDs via promo codes + UTMs.

Explicitly rejected: **AI actors / synthetic testimonials / cloned-voice
personas.** Endpaper's positioning is no-AI and nothing-fake; synthetic
faces making first-person practice claims would be brand-corrosive and
are fabricated-endorsement territory besides. The product is the actor —
the screen itself is the pattern interrupt. Human moments are Wendell,
on camera, for real.

## Build order (machine side)

1. `tools/content/` — Playwright render harness: seed → capture stills
   (all ratios, both themes) → record choreography clips
2. Card templates (`tools/content/cards/`) — rule / stat / quote, token
   system, PNG out
3. Pack assembler + captions writer → `content/packs/YYYY-WW/`
4. The Monday Routine + delivery to phone
5. Scoreboard doc + UTM link set

Steps 1–3 are a day or two of work and produce the first pack
immediately; 4–5 are an hour. Say go and the first pack exists this
week.

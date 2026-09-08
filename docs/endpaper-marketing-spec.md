# Endpaper — Marketing Spec (portable)

*Snapshot 2026-09-08. Self-contained: everything a collaborator or another
chat needs to work Endpaper's marketing without the session history.
Owner: Wendell Barton (hello@wendellbarton.com), posting from EEST.*

---

## 1. The product

**Endpaper** (endpaper.space) — an iOS journal that reads your writing back
to you. Four non-negotiable rules: **permanence** (entries seal at
midnight, no edits, no deletions), **no AI** (reflections are pattern
recognition over your own words, verbatim — never analysis, never a
chatbot), **no analytics/tracking**, **no accounts** (on-device +
private iCloud; nothing on any server of ours).

Core loop: one quiet page a day → each day you write, a dot fills in →
every week and month, a **reflection** hands the writing back as a deck
of cards (the word that kept surfacing, the line written large, the
question you asked yourself, who you talked about, when/how much you
wrote). Voice notes transcribe on-device. Photo/file import exists but
ships hidden.

**State (1.0.4, build 21 on TestFlight; 1.0.3 in App Store review):**
free model — writing is free forever; **membership** ($39.99/yr, first
week free via ASC intro offer) gates reflections. The first weekly
reflection plays free and its closing beat is the offer. New onboarding
is a six-beat "deck" in the reflections' own design language; a daily
dot-dive splash counts down to the next reflection; first-week ghost
prompts are deliberately charged (jealousy, guilt, pain, excitement);
share cards v1 (a chosen line as a styled card; a month as a
constellation of dots) turn free users into distribution.

Marginal cost per free user: $0 (no servers, no inference).

## 2. Positioning & messaging

**Spine: reflection over permanence.** Permanence is the supporting trait.
- Store subtitle: **"A journal that reads you back"**
- Thesis line: **"You write. It reads you back."**
- Mental-health framing (directive 2026-08-28, product unchanged):
  **"Never forget what you want to say in your next session."**
- No-AI is the counter-programming wedge (strong in comments/stitches
  against AI-journal content; not a growth engine by itself).
- Price line: "about the price of one good paper notebook."

**Voice rules:** quiet, direct, first person where the maker speaks.
No exclamation marks, ever. Intensity lives in the claim, never the
delivery — a quiet accusation beats a loud invitation. Never fake an
attribution (quotes, credentials, quotes from partners).

## 3. Audiences (working personas)

Four synthetic personas from the customer workshop, two creative lanes:
- **Returner** — lapsed journaler, often in/around therapy. Lane:
  quiet-honest (dawn kitchen, plain light). Angles: "The $200 silence"
  (the real thing gets said in the car after the session), "Venting
  isn't processing."
- **Founder/Operator** — the 3am board meeting; thoughts not safe to say
  to team/investors/partner. Lane: desk at night / quiet-luxury.
- **Aesthete** — curated life, inner life still in a notes app. Lane:
  quiet-luxury b-roll (pool, hotel, first class). Angles: "The
  unconsidered corner", "The most expensive thing you own" (attention).
- **New-Chapter** — breakup/move/career shift. Lane: quiet-honest.
  Angles: "The middle has no witnesses", "You won't remember this year
  the way you think."

Full angle scripts: `tools/content/audience-angles.md`. Test protocol:
format constant so audience is the only variable; one angle per 2–3
days, never two personas the same day; score saves + comments per reach,
DMs, follower quality; log as `AUDIENCE-TEST RET-1` etc.

**Stowed frame (Leara):** a man crediting his fiancée/partner in the
content resonates with women audiences ("My fiancée, who's a
psychologist, recommends…"). Use only true claims, cleared with her; tag
posts `FRAME FIANCEE` so lift is separable from the angle.

## 4. Market reality (benchmarks)

| App | Scale | Sells |
|---|---|---|
| Finch | ~$2–4M/mo, bootstrapped, best-in-class D30 | self-care via a virtual pet (product-generated shareability) |
| Day One | ~$400K/mo, 10M+ installs since 2011 | the trusted archive; "On This Day" resurfacing; moving *more* free |
| Stoic | ~$1.5M ARR | emotional understanding via prompts/routines (outcome framing) |
| Rosebud | $6M seed, 7.5k paying | AI that reflects writing back — our exact spine, via AI |
| Apple Journal | free default | no threat; Journaling Suggestions API is free on-device intelligence |

Lessons: nobody grew on brand aesthetics alone; winners have a product-
generated shareable artifact, a face, a paid budget, or a decade of
ASO. People pay for "understand yourself," not "write daily." Solo-
founder realistic ambition: Stoic-scale.

## 5. Channel performance to date (honest)

- **Instagram (@endpaper.space):** ~4 weeks of 2 posts/day faceless
  quote Reels → ~100 views/post, **8 followers, zero attributable
  downloads.** Month-over-month down. Verdict: faceless quote account
  = wallpaper; demoted to shopfront maintenance.
- **Founder Reel baseline (Aug 26, 52s desk, overlay "Have you read
  it?"):** 205 views (2x quote baseline), 94.6% non-followers, **skip
  rate 74.7% vs 88.6% account-typical** (the face wins the stop), but
  **avg watch 5s** with a retention cliff by ~8s; distribution dead
  after day one; 0 profile taps. Read: the face earns the audition,
  the opening loses it.
- **Wendell's personal LinkedIn (1,084 followers):** 798 views on one
  design post — ~8x any Endpaper IG post. Largest owned reach.
- **One product-explainer IG post:** 26 views, 15.4% ER (highest of
  the month). The product story converts; it gets no attention.
- **Eden mining (IG, 100k–1M creators, 3x+ outliers, last quarter):**
  zero quote cards among journaling outliers. Winners: **situational
  journaling instruction** ("someone's comment hurt you? go home and
  write THESE questions" — 257x, 4.7M views), a **prompt-list
  carousel** (14x, 12.4k comments), a talking-head "how to journal
  honestly" tutorial (12.9x).

## 6. The content system (as it runs today)

**Daily kits (maintenance spine):** two quote-motion Reels/day rendered
from `tools/content/render-quote.mjs` — the huge first letter on frame
one is the pattern interrupt, type-on, day header, ENDPAPER.SPACE
footer. **US-flipped slots:** dark cut dated *yesterday* (~9–10pm stamp)
posted in Wendell's morning = US West evening; light cut dated *today*
(~7am) posted ~21:00 EEST = US morning. Confrontational lines → dark;
softer → light. Caption format: `From {Last name} - Thought of
{Weekday}, {Mon} {D}th at {time}` (author) or `Thought of …`
(unattributed). First comment, always: `I wrote this in the Endpaper
app`. Posted manually with IG catalog audio; Eden API posts go up
silent (first comment manual) — use only when explicitly asked.

**Question cuts (Sunday franchise, 1–2/week):** same renderer, a
question with the loaded phrase emphasized, caption `Asked myself on
{Weekday}, {Mon} {D}th at {time}`. Mirrors the app's "You asked
yourself" beat. Bench is session-framed ("What do I keep calling fine
that isn't?", "What would I tell a friend who brought me this?" …).
Comment rate vs quotes decides permanence (verdict pending — Eden
analytics sync stalled since Aug 17).

**Founder / situational face content (the growth bet):** ≤20–30s, the
pain in the first spoken line, overlay carries stakes not a referent
("10 years of journals. Never read them once." > "Have you read it?"),
app named only at the end, hard cut for loops. Spawned hooks: the 20s
recut of existing footage; "Someone said something that stung — don't
answer, write these three questions"; "Never forget what you want to
say in your next session." Post identical files to TikTok same day.
Founder cadence: one claim per week in the evening (US-morning) slot;
that day runs the morning kit only. Never a founder piece and an
audience-test angle on the same day (flagship isolation: nothing else
within 3h of a flagship).

**Tests queued:** one prompt-list carousel ("5 questions to write before
your next session"; comments are the metric); one LinkedIn founder
build-story post; optional $100–200 boost on the best founder cut to
read install conversion fast.

**Weekly rhythm:** Monday pack (40 assets: app views light/dark, rule
cards, quote video; pick 3–5, mark hooks `live`); Friday kill/scale
(`dead` / `winner` / `rested`, spawn same-family variants) — statuses
live in `tools/content/hooks.md`; monthly strategy breakdown on Fridays
via Eden analytics when the sync works.

## 7. Creative rules (kit spec + hook craft)

- Quote Reels stay clean: no overlays on the aesthetic; the letter is
  the hook. Frame one must show the huge letter (a scroll must never
  catch an empty page). ~0.5s hang; emphasis press by skew+stroke, never
  re-wrapping.
- Hook psychology applied to flagships (first 1.5s of audio AND first
  frame): curiosity gap, information gap, loss aversion, self-relevance,
  prediction error, generation effect, contrast, specificity. Examples
  in our voice: "There's one thing your journal knows that you don't."
  "You forget most of your days — not the big ones, the ones that made
  you." "Guess how many of your own days you actually remember."
- Bias quote mining toward lines whose FIRST word carries the punch
  (Anxiety…, Numbness…, Overthinking…); prefer known authors; verified
  attributions only.
- Charged-first-word + author caption + first-letter thumbnail was the
  best quote combination measured (1.5x, Kierkegaard) — but quote
  micro-tuning is frozen; the format is maintenance now.

## 8. Assets on hand

- **Store screenshots v3** (7 lockups × 3 sizes, reflections grammar):
  reads-you-back opener → ghost/ink split → week card → voice card →
  therapy question card → fanned deck → sealed closer.
- **Listing copy** (`docs/endpaper-store-listing.md`): subtitle,
  promo, reflection-first description, keywords, What's New. No
  scanning/import language anywhere.
- **Founder scripts** (`tools/content/founder-scripts.md`): never-read-
  them-back flagship; can't-edit-on-purpose; therapy. One recorded.
- **Audience angles** (`tools/content/audience-angles.md`): 8, two per
  persona.
- **Strategy docs:** `tools/content/strategy-2026-08-28.md` (first
  Friday breakdown + mining), `tools/content/hooks.md` (hook library,
  psychology table, pillars, signals, live log of every post).
- **Weekly packs:** `node make-pack.mjs` → 40 assets + captions.md +
  THIS-WEEK.md.
- Customer-workshop artifact (4 personas, two-lane recommendation).

## 9. Store listing (paste-ready)

- Name: `Endpaper — Journal` · Subtitle: `A journal that reads you back`
- Promo: *You write. It reads you back. Weekly and monthly reflections
  built from your own words — no AI, no analysis, no one reading but
  you.*
- Keywords: `journal,diary,journaling,reflection,private,writing,daily,
  notebook,voice,minimal,mindful,therapy`
- 1.0.4 (free model) will need a fresh What's New: "Free to write.
  Reflections are a membership — your first one's on me."

## 10. Measurement

Per post: views, skip rate vs account-typical, average watch (target
≥12–15s on face cuts), saves + comments per reach, shares, profile
activity, follower delta. Tags in the live log: `AUDIENCE-TEST {persona}`,
`FRAME FIANCEE`, `FOUNDER`. Success line for the recut: avg watch >12s
or skip rate <70% — either widens distribution automatically.
Known gap: Eden analytics warehouse has no IG rows since Aug 17; needs
a re-auth/tracking restart in the Eden app before any data-driven
pass.

## 11. Decisions made / open

**Made:** reflection-first spine; free model with membership for
reflections; founder gate opened (first Reel posted); quotes demoted to
maintenance; questions Sundays; fiancée frame stowed; Notebook keeps
its editorial drop cap.

**Open:** question-cut verdict (needs data); retune the daily kit
cadence down (14/wk → ~4/wk) once face content is flowing; TikTok
cross-post start; the LinkedIn post; paid boost yes/no; Cyrillic
companion serif before any Russian push (bundled faces lack Cyrillic);
"a year ago today" resurfacing feature (retention, cheap); motion
share card (type-on video export) as share v2.

**Next two weeks:** ship 1.0.3 → recut founder piece 1 at ≤20s + TikTok
→ shoot the three spawned founder/situational hooks in the ≤30s shape →
prompt-list carousel test → LinkedIn build-story → read everything
against the founder baseline (74.7% skip / 5s avg watch).

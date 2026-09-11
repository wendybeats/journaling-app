# Endpaper — PM brief: the early glimpse, and product analytics

Status: BRAINSTORM, nothing implemented. Written 2026-09-11 against the
1.0.4 codebase (TestFlight build 20; next archive 21). Storyboard of the
current first-reflection flow: `docs/reflection-storyboard/` (19 screens
+ 3 proposed).

---

## 0. Two things the code says that change the brief

**0.1 The first Sunday is silent for a lot of installers — and the app
promises otherwise.** `Reflect.lastCompletedWeekStart` makes the weekly
cover the completed Sun–Sat week, and `WeeklySignal.sufficient` needs
≥3 written days AND ≥300 words. So:

| Install day | Days possible before Sunday | First Sunday |
|---|---|---|
| Sun–Wed | 4–7 | reflection (if they wrote 3+ days) |
| Thu | 3 | reflection only if they wrote every day |
| Fri, Sat | 1–2 | **silent — nothing arrives until Sunday +8** |

Meanwhile the daily arrival says "Your reflection is 2 days away", the
Today line says "Reflection in 2 days", and the Sunday 09:00 note says
"Your weekly reflection is here" — all gated on consent only, none on
sufficiency. A Friday installer is promised something on day 3 and gets
silence, plus a notification for it. That is the exact hole the glimpse
fills, but the promise itself must also be fixed in the same build
(§1.6). This is the biggest finding in the brief.

**0.2 The paywall lands on the second Sunday, not day 7.** The first
weekly is free (`firstWeeklyUsed`); the ask is the offer beat at the end
of that deck, and the hard gate is the locked "Join to read it" card on
Sunday two (day 8–14 depending on install day). So the funnel we need to
see is: install → onboarding → first entry → writing day 2 → glimpse →
free weekly (opened / completed to the offer) → locked weekly → join.
Today none of it is visible. §2 exists for this.

---

## 1. The early glimpse — v2 (2026-09-11, after Wendell's review)

Supersedes v1 (the card + two-beat deck). Decisions taken: no separate
surface, no consent requirement, inline on the page, tap for the
dialogue, at most once a day. Primary job: a retention lever to D7.

### 1.0 First: the reflection is calendar-anchored today, and must not be
`Reflect.lastCompletedWeekStart` and `daysUntilReflection` are both
built on Sunday; the two weekly notes are weekday-fixed (Sat 22:00,
Sun 09:00). So a Friday installer's "week" is two days long. The new-user
experience has to be the same whatever day they start:

- **Anchor = `AppKeys.firstDay`** (stamped on first-ever open in 1.0.4;
  fall back to the earliest entry day for upgraders).
- **Day 0–6 = the seven ghost prompts** (the array already has exactly
  seven, indexed by days since firstDay).
- **Day 7 (firstDay + 7, the D7 of retention math) = first reflection**
  covering days 0–6, and the offer beat at its end. Countdown runs
  7 → "tomorrow" → "ready". Then every 7 days on the same weekday; the
  locked card lands on day 14.
- Notes become relative: day 6 at 22:00 ("arrives tomorrow"), day 7 at
  09:00 — via `UNCalendarNotificationTrigger` on the install weekday.
- Monthly recaps stay calendar months.
- **First-week sufficiency is lowered** to ≥2 written days and ≥150
  words (regular weeks keep ≥3 / ≥300). If even that isn't met, day 7
  shows a quiet card — *Not enough to reflect on yet. Your first
  reflection moves to {weekday}.* — and the offer waits a week. The
  Sunday-style promise into silence goes away.

Engine cost is small: `weeklySignal(start:)` already takes any start
date; the change is in `pendingWeekly`, `daysUntilReflection`, the notes,
and the week label.

### 1.1 How often it would actually fire — case examples
The rule under test: a stem (≥4 letters, not a stopword) with ≥3
mentions across ≥2 written days, after ≥2 written days and ≥N total
words. Word-frequency reality: in 250 words of natural journaling the
top content word appears 3–5 times, so the pattern half of the rule is
nearly always met once the word floor is — **the floor is what decides
when it fires, and the risk is over-firing, not silence.**

| Persona | Writing | Fires (200-word floor) | Fires (120-word floor) | Note |
|---|---|---|---|---|
| A · one-liner | 25–40 words/day, most days | day 6–7 or never | day 4–5 | The churn-risk cohort; 200 words puts the lever after the week is lost. |
| B · a paragraph | 100–150 words/day | day 3 (~90% likely), else day 4 | day 2–3 | The target user. Word will be "work", a name, or a feeling. |
| C · the dump | 400+ words day 0, then sporadic | the first day-2 entry, whatever its length | same | Day 0 alone already has stems at 2–3 mentions. |
| D · skipper | writes day 0, 2, 4 | day 2 or 4 | day 2 | Fine — days are counted, not streaks. |
| E · voice notes | 200+ words/day, spoken | day 2 | day 2 | Spoken text repeats words more; expect 2–3 candidate stems at once. |

Measured on the synthetic parity corpus (~270 words/day, templated
sentences, so an upper bound): fires on day 3 for 100% of 264 rolling
starts, and with "one new stem per day" it fires **6 of 7 days**. The
words it picked: boat, house, corner, kind, said, didn. Two lessons:

1. **Cap it.** First glimpse at the floor; any later glimpse needs a
   *stronger* pattern (≥5 mentions across ≥3 days, a new stem), and at
   most two before the first reflection. Once a day is the ceiling,
   not the target.
2. **Flat words.** The tokenizer lets "said", "kind", "didn" (from
   "didn't" — the apostrophe split) and "work" through. Add a glimpse-only
   flat list (~40 words: said, kind, work, morning, night, home, people,
   today…) and fix the contraction fragments (didn/wasn/couldn) in the
   tokenizer — that fix also touches the weekly thread beat and the JS
   parity suite, so it's its own change.

**Recommendation: 120-word floor, 2 written days.** It moves persona A's
lever inside the week, and B fires on day 2–3 where D7 retention is
decided. The pattern bar (3 mentions / 2 days) already stops one-day
dumps.

### 1.2 The surface — inline highlight, tap, dialogue
- **Where it appears:** on **committed** text — the entry sections
  above the live editor on Today, and the Notebook. Never inside the
  live UITextView (the WrittenFormat pipeline lives there; a tappable
  run mid-typing is both the distraction and the bug farm). When a word
  crosses the bar mid-entry, nothing happens until the next render of
  the page after the section commits.
- **What it looks like:** the most recent occurrence of the word gets a
  soft ink-wash behind it (Tokens raised tint at ~40%), no underline, no
  colour. One word, one place. Rendering only — the entry text is never
  touched (permanence intact).
- **Tap → the dialogue:** a compact inverted sheet from the bottom
  (`presentationDetents([.height(240)])`): kicker *Something is starting
  to emerge* · the word, Newsreader italic · *4 times across 2 days* ·
  *Your first reflection is in 4 days.* Tap anywhere to dismiss. No
  quote, no offer, no share.
- **After the tap** the highlight fades. Untapped, it fades at midnight
  with the day. The Notebook never shows a highlight.
- **Consent:** not required (unasked = eligible). An explicit *No
  thanks* to reflections is respected — no highlights.
- **Frequency:** at most one highlight per day, one per stem ever, at
  most two before the first reflection, none on reflection day.
- **Reduce Motion / VoiceOver:** highlight is static; the run gets an
  accessibility hint *Tap: this word keeps coming back.*

### 1.3 What it is not
No notification, no card in the reflection slot, no archive, no offer,
no share card, no analysis. Silence when nothing clears the bar.

### 1.4 Effort
`Reflect.glimpseCandidates(corpus:)` (reuse tokenizer + flat list, ~50
lines), `GlimpseState` in UserDefaults (fired stems, last-fired day,
count), the highlight run in `EntrySection` (attributed `Text` run with
a background), `GlimpseSheet`, plus the cadence change in §1.0 and the
tokenizer fix. About two days with the cadence change; QA §18.

### 1.5 Still open (small)
1. 120 or 200 word floor — recommend 120.
2. Highlight fades on tap, or stays faint until midnight — recommend
   fades on tap.
3. First-week sufficiency at 2 days / 150 words — recommend yes.

---

## 2. Product analytics (PostHog)

### 2.1 The rule change, in words
Old rule: *no analytics.* New rule: **we count taps, never words.**
Anonymous product-state events; never journal content, words, names,
topic words, reflection contents, exact counts, or ad identifiers. This
is a stronger, more specific promise than "no analytics" and it survives
scrutiny. It has to be changed everywhere at once:

| Where | Today | Change to |
|---|---|---|
| Onboarding AccountSlide | "No profile, no analytics, nothing read by anyone but you." | "No profile, nothing read by anyone but you. We count taps, never words." |
| Settings footer | "Endpaper · no analytics, no tracking" | "Endpaper · no tracking · we count taps, never words" + toggle (§2.3) |
| App Store description ("Only yours") | "No analytics. No tracking." | "No tracking, no ads. We see that a page was written, never what it says." |
| App Store privacy label | Data Not Collected | **Data Not Linked to You → Product Interaction** (Analytics purpose). Must be updated before the next submission or review will flag the mismatch. |
| site/privacy.html | "no analytics, no tracking" (×3 incl. the bullet list) | New section: what is counted (event names), what never leaves the device, how to turn it off, EU hosting, retention. |
| docs/endpaper-marketing-spec.md rule 3 | "no analytics/tracking" | "no tracking; anonymous usage counts, never content" |
| Store screenshots | check screen 2 copy | only if it says "no analytics" |

### 2.2 Recommendation: PostHog, EU cloud
- **Host:** `eu.i.posthog.com` (EU data residency reads well in the
  privacy page; free tier 1M events/month is years of runway).
- **SDK:** `posthog-ios` via SPM (xcodegen `packages:` + a target
  dependency). It ships its own privacy manifest; the app also needs a
  `PrivacyInfo.xcprivacy` (none exists today) declaring UserDefaults use
  (reason CA92.1).
- **Config:** autocapture OFF, session replay OFF, lifecycle events OFF
  (we send our own `app_opened`), `personProfiles = .never` so events are
  person-less (cheaper, and literally no profile), GeoIP disabled at the
  project level (or accept country only — your call), no IDFA, no ATT
  prompt (we don't track across apps, so ATT is not required).
- **Identity:** one random UUID in UserDefaults (not iCloud KV — a
  reinstall is a new anonymous user, which is honest). Never `identify`.
- **Opt-out:** Settings toggle *Share anonymous usage*, default on,
  respected via `optOut()`. Apple doesn't require opt-in for non-tracking
  analytics.

### 2.3 Event schema v1
Every event carries super properties: `app_version`, `build`,
`days_since_install_bucket` (0 / 1–3 / 4–7 / 8–14 / 15+), `consent`
(yes/no/unasked), `membership` (none/trial/active), `install_week`
(ISO week — cohorting). Once-per-install events are stamped in
UserDefaults so re-evaluation can't double-fire.

| Event | Fires | Properties |
|---|---|---|
| `app_opened` | first open of each calendar day | — (gives DAU and retention without content) |
| `onboarding_completed` | Begin tapped on ReadyBeat | — |
| `first_entry_created` | first entry ever saved | — |
| `writing_day` | once per calendar day with ≥1 entry, at first save | `day_index` (1..n since install), `words_bucket` (<100 / 100–500 / 500+) |
| `consent_answered` | consent card | `answer` |
| `early_insight_eligible` | glimpse card shown | — (no word, ever) |
| `early_insight_opened` / `_dismissed` | See it / Later | — |
| `weekly_reflection_eligible` | ready card shown | `locked`, `week_index` |
| `weekly_reflection_opened` | deck presented | `week_index` |
| `weekly_reflection_completed` | last beat reached | `week_index`, `beats` (count) |
| `paywall_viewed` | offer beat / locked card tap / monthly gate / settings sheet | `surface` |
| `trial_started` / `subscription_started` / `subscription_restored` / `purchase_failed` | StoreKit result | `surface`, `reason_bucket` |
| `notification_permission` | after the system prompt | `granted` |
| `share_card_created` | ShareLink used | `kind` (line / constellation) |

`second_writing_day` is `writing_day` with `day_index = 2` — one event,
filter in PostHog. Names kept from your list where they map 1:1.

### 2.4 The guard, in code
One `Analytics.track(_ event: Event, _ props: [Prop: Value])` where
`Event` and `Prop` are closed enums and `Value` is Int/Bool/enum-string
only — there is no API that accepts a free `String`, so journal content
cannot be sent by accident. A unit test asserts the enum list matches
this table.

### 2.5 Dashboards, day one
1. The funnel: `onboarding_completed → first_entry_created →
   writing_day[2] → early_insight_opened → weekly_reflection_opened →
   weekly_reflection_completed → paywall_viewed → subscription_started`.
2. Retention by `writing_day` (D1 / D3 / D7 / D14).
3. Glimpse effect: D7 retention and weekly-opened rate, cohort
   `early_insight_opened` vs eligible-not-opened vs not eligible.

### 2.6 Effort and risk
About one day: SDK + config + `Analytics.swift` + ~14 call sites + the
copy changes + privacy manifest + Settings toggle. Then the App Store
privacy questionnaire before submission. Risk is review mismatch (label
vs SDK) — the label change goes first. Brand cost is small if the copy
is honest and specific.

---

## 3. Sequencing (recommendation)
Fold both into the build that is already in QA — 1.0.4 is not submitted,
and the privacy-label change wants its own review anyway. Order inside
the build: analytics first (so the glimpse is measured from its first
day), then the §1.6 promise fixes, then the glimpse once the three
decisions come back. Next archive stays 1.0.4 / 21.

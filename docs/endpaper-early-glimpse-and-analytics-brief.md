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

## 1. The early glimpse

### 1.1 Job
Prove the proposition before the first Sunday: *your words say
something back*. One moment, once per install, restrained. It is not a
reflection, does not get archived, and never carries the offer.

### 1.2 Readiness — what fires it
All on-device, on the existing engine (same tokenizer, stopwords and
stemmer as `Reflect.weeklySignal`, so parity with the deck is automatic).
Eligibility gates, then one pattern test:

| Gate | Value | Why |
|---|---|---|
| Consent | `yes` | It's a reflection-family surface; the consent card comes first. |
| Distinct written days | ≥ 2 | Days are the habit signal, not words. 2 (not 3) so a Thursday installer can qualify by Saturday. |
| Total words since install | ≥ 200 | Cheap floor so one-line days don't qualify. |
| Pattern | one stem with ≥ 3 mentions across ≥ 2 days | The weekly's own second arm (`count ≥ 3 && days ≥ 2`). Names excluded in v1 (topic words only). |
| Never fired | `AppKeys.glimpseShown == nil` | Once per install, ever. |
| No competing arrival | no pending weekly, first weekly not yet seen | The weekly always wins the slot; after the first weekly the glimpse is pointless. |

Not a score with weights — three gates and a pattern. If nothing clears
the pattern bar, Endpaper stays quiet and the countdown remains the only
promise. No sentiment lexicon, no "charged word" bonus: that would be
analysis, and the brand rule is counting.

### 1.3 When it appears
At the same point the reflection slot is evaluated today
(`ReflectionFlowHost.evaluate`, Today `onAppear`) — so it shows on the
**next open after** the qualifying entry, never mid-sentence and never
auto-presented. Same rule as the ready card ("nothing auto-presents",
QA 2026-09-05). If they tap **Later**, it re-offers on the next open once,
then drops for good (`glimpseShown` stamped either way).

### 1.4 The surface
Storyboard G1–G3. Three moves, no more:

1. **Today card** (ready-card grammar, same slot): title
   *Something is starting to emerge.* · meta *One word keeps coming back*
   · `See it →` / `Later`. The card deliberately does **not** show the
   word — Today is a surface other people can glance at.
2. **The glimpse** (inverted, one beat, thread grammar): kicker
   *Something is starting to emerge* · the word in Newsreader italic 54 ·
   *You've used this word 9 times since you started writing.* No quote,
   no count-ups, no dots-drawing. One page.
3. **The close**: *Keep writing.* · *Your first weekly reflection is
   Sunday.* · `Continue`. When this week can't qualify (§0.1) the line
   says the date instead: *Your first weekly reflection arrives Sunday,
   Sep 20.*

Not archived in the Notebook (it isn't a reflection). No notification for
it. No share card from it (v1). Free, always — never gated.

### 1.5 Edge cases
- Wrote 1,000 words on day one only → not eligible. Deliberate: day two
  is the thing we want to reward.
- Consent "no" → never. Consent flipped on later in Settings → eligible
  from then.
- The word is unflattering ("drunk", an ex's name) → it's their word, in
  private, behind a neutral card. Names are excluded in v1 anyway.
- Reduce Motion → both beats static, as PromptBeat already handles.
- Reinstall → fires again (state is UserDefaults, not iCloud KV). Fine.

### 1.6 Ship with it (same build, non-negotiable)
- Countdown line + daily arrival: when the current week cannot reach
  sufficiency (fewer than 3 writable days left and <3 written), say
  *First reflection Sunday, Sep 20* instead of *Reflection in 2 days*.
- Sunday 09:00 note: only schedule it when a weekly will actually be
  pending (compute at Saturday seal, or gate the body on sufficiency).
  Today it can fire into silence.

### 1.7 Effort
About one engineering day: `Reflect.glimpseSignal(corpus:)` (reuse the
tokenizer; ~40 lines), `AppKeys.glimpseShown`, `GlimpseView` (two
PromptBeats in a TabView, like WeeklyCardView), the card in
`ReflectionFlowHost`, the §1.6 fixes, QA §18. Swift-only (no JS parity
entry — it is not archived and not part of the reference engine).

### 1.8 Decisions I need from you
1. **2 written days or 3?** I recommend 2 (Thursday installers).
2. **Next open, or same visit after the entry seals?** I recommend next
   open (keeps "nothing auto-presents").
3. **Does the countdown switch to a dated line when the week can't
   qualify?** I recommend yes; it's a bug today regardless of the glimpse.

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
